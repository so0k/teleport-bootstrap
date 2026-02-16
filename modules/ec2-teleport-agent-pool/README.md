## Deploy Teleport Agents with Terraform

Ref:

- https://goteleport.com/docs/agents/deploy-agents-terraform/

AMI source: `../../packer/build.pkr.hcl`

1. Creates an ASG of teleport agents
1. Creates Teleport join token for IAM Auth
1. Manages Teleport Agent config through SSM ParameterStore for confd instance on agent
