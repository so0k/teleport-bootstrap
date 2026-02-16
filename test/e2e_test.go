package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	loggers "github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

// Occasionally, a Packer build may fail due to intermittent issues (e.g., brief network outage or EC2 issue). We try
// to make our tests resilient to that by specifying those known common errors here and telling our builds to retry if
// they hit those errors.
var DefaultRetryablePackerErrors = map[string]string{
	"Script disconnected unexpectedly": "Occasionally, Packer seems to lose connectivity to AWS, perhaps due to a brief network outage",
}
var DefaultTimeBetweenPackerRetries = 15 * time.Second

const DefaultMaxPackerRetries = 3

var DefaultTimeBetweenTerraformRetries = 5 * time.Second

const DefaultMaxTerraformRetries = 5

var logger = loggers.Default

func TestTerraformPackerTeleportAgent(t *testing.T) {
	t.Parallel()

	workingDir := "./terraform"
	awsRegion := "us-east-1"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		deleteAMI(t, awsRegion)
	})

	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		undeployUsingTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		buildAMI(t, awsRegion)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		// Wrap the parallel tests in a synchronous test group to ensure that the main test function (the one calling
		// `deployUsingTerraform` and `undeployUsingTerraform`) waits until all the subtests are done before running the deferred function.
		t.Run("deployTerraformGroup", func(t *testing.T) {
			deployUsingTerraform(t, awsRegion, workingDir)
		})
	})

	test_structure.RunTestStage(t, "validate", func() {
		testSSMConnection(t, awsRegion, workingDir)
	})
}

func buildAMI(t *testing.T, awsRegion string) {
	packerOptions := &packer.Options{
		// run from packer dir
		WorkingDir: "../packer",
		Template:   "build.pkr.hcl",
		// Only build the Amzn2 AMI
		Only: "amazon-ebs.amzn2",

		// Variables to pass to our Packer build using -var options
		// assuming .auto.pkrvars.hcl are loaded
		Vars: map[string]string{
			"pr": "true",
		},
		VarFiles: []string{
			".auto.pkrvars.hcl",
		},

		// Configure retries for intermittent errors
		RetryableErrors:    DefaultRetryablePackerErrors,
		TimeBetweenRetries: DefaultTimeBetweenPackerRetries,
		MaxRetries:         DefaultMaxPackerRetries,
	}
	amiID := packer.BuildArtifact(t, packerOptions)
	// Save the AMI ID so future test stages can use them
	test_structure.SaveArtifactID(t, ".", amiID)
}

func deleteAMI(t *testing.T, awsRegion string) {
	// Load the AMI ID and Packer Options saved by the earlier build_ami stage
	amiID := test_structure.LoadArtifactID(t, ".")
	aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiID)
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if len(value) == 0 {
		return defaultValue
	}
	return value
}

func deployUsingTerraform(t *testing.T, awsRegion string, workingDir string) {
	// A unique ID we can use to namespace resources so we don't clash with anything already in the AWS account or
	// tests running in parallel
	uniqueID := strings.ToLower(random.UniqueId())

	// Give this EC2 Instance and other resources in the Terraform code a name with a unique ID so it doesn't clash
	// with anything else in the AWS account.
	namePrefix := fmt.Sprintf("e2e-%s", uniqueID)
	amiID := test_structure.LoadArtifactID(t, ".")
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: workingDir,
		EnvVars: map[string]string{
			"TF_TELEPORT_IDENTITY_FILE_PATH": getEnv("TF_TELEPORT_IDENTITY_FILE_PATH", "./teleport-identity"),
			"TF_TELEPORT_ADDR":               getEnv("TF_TELEPORT_ADDR", "0.0.0.0:3025"),
		},
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
			"ami_id":      amiID,
			"aws_region":  awsRegion,
		},
	})

	test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

// Undeploy using Terraform
func undeployUsingTerraform(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)

	terraform.Destroy(t, terraformOptions)
}

func testSSMConnection(t *testing.T, awsRegion string, workingDir string) {
	// Load the Terraform Options saved by the earlier deploy_terraform stage
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	asgName := terraform.OutputRequired(t, terraformOptions, "asg_name")

	// It can take a minute or so for the ASG to scale up, so retry a few times
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second

	aws.WaitForCapacity(
		t,
		asgName,
		awsRegion,
		maxRetries,
		timeBetweenRetries,
	)
	instanceID := aws.GetInstanceIdsForAsg(t, asgName, awsRegion)[0]

	timeout := 5 * time.Minute
	aws.WaitForSsmInstance(t, awsRegion, instanceID, timeout)
	checkLogs(t, awsRegion, instanceID, timeout, []ssmCommand{
		{command: "sudo cloud-init status --wait || sudo cat /var/log/user-data.log", printf: "cloud-init status:\n\n%s\n"},
		{command: "sudo cat /var/log/user-data.log", printf: "user-data log:\n\n%s\n"},
		{command: "sudo journalctl -u confd", printf: "confd log:\n\n%s\n"},
		{command: "sudo cat /etc/teleport.yaml", printf: "/etc/teleport.yaml:\n\n%s\n"},
		{command: "sudo journalctl -u teleport", printf: "teleport log:\n\n%s\n"},
	})
}

type ssmCommand struct {
	printf  string
	command string
}

func checkLogs(t *testing.T, awsRegion string, instanceID string, timeout time.Duration, commands []ssmCommand) {
	for _, c := range commands {
		result := aws.CheckSsmCommand(t, awsRegion, instanceID, c.command, timeout)
		assert.Equal(t, int64(0), result.ExitCode)
		logger.Logf(t, c.printf, result.Stdout)
	}
}
