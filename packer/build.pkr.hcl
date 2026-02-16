packer {
  required_version = "~> 1.9.0"
  # https://www.packer.io/plugins/builders/amazon
  required_plugins {
    amazon = {
      version = "~> 1.3"
      source  = "github.com/hashicorp/amazon"
    }
    git = {
      version = "~> 0.3.2"
      source  = "github.com/ethanmdavidson/git"
    }
  }
}
data "git-commit" "head" {}

locals {
  truncated_sha = substr(data.git-commit.head.hash, 0, 8)
  author        = data.git-commit.head.author
  identifier    = "packer-%{if var.pr}pr-%{endif}teleport-agent-${var.architecture}"
  ami_name      = "${local.identifier}-${local.truncated_sha}"

  # match kms key to publish key, to avoid re-encrypting the image
  kms_key_id = try(
    var.ami_region_kms_key_ids[var.aws_region],
    "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:alias/packer-ebs",
  )
}

source "amazon-ebs" "amzn2" {
  # output ami name
  ami_name              = local.ami_name
  force_deregister      = true
  force_delete_snapshot = true
  ami_description       = "Built from a commit by ${local.author}"
  instance_type         = "${lookup(var.instance_type, var.architecture, "error")}"

  # https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs#block-devices-configuration
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = true
    kms_key_id            = local.kms_key_id
    volume_size           = 4
    volume_type           = "gp3"
  }
  region    = var.aws_region
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  # AWS AMI data source lookup
  source_ami_filter {
    most_recent = true
    owners      = ["amazon"]
    filters = {
      name                = "*amzn2-ami-minimal-*"
      architecture        = var.architecture
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
  }
  communicator = "ssh"
  ssh_username = "ec2-user"
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    OS_Version                       = "Amazon Linux 2"
    Base_AMI_ID                      = "{{ .SourceAMI }}"
    Base_AMI_Name                    = "{{ .SourceAMIName }}"
    App                              = "Teleport Agent"
    Amazon_AMI_Management_Identifier = local.identifier
  }

  # publish to AWS Organization
  ami_regions        = var.ami_regions
  region_kms_key_ids = var.ami_region_kms_key_ids
  ami_org_arns       = var.ami_org_arns

  # If you have set either `region_kms_key_ids` or `kms_key_id`, `encrypt_boot` must also be `true`.
  encrypt_boot = true
}

build {
  sources = [
    "source.amazon-ebs.amzn2",
  ]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /tmp/build-assets /opt/teleport/scripts",
      "sudo chown ec2-user:root /tmp/build-assets /opt/teleport/scripts",
      # minimal amazon linux 2 doesn't have aws-cli, ssm-agent installed
      "sudo yum -y install amazon-ssm-agent aws-cli"
    ]
  }

  provisioner "file" {
    source      = "assets/"
    destination = "/tmp/build-assets"
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/opt/teleport/scripts"
  }

  provisioner "shell" {
    script = "scripts/install-confd.sh"
    environment_vars = [
      "CONFD_VERSION=v${var.confd_version}",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  provisioner "shell" {
    script          = "scripts/install-datadog.sh"
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  provisioner "shell" {
    script = "scripts/install-teleport.sh"
    environment_vars = [
      "TELEPORT_VERSION=${var.teleport_version}",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
