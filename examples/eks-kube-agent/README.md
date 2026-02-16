# EKS Kube Agent Example

This example provisions the AWS-side resources needed to run Teleport kube
agents on one or more EKS clusters using the **IAM join method** and **IRSA**
(IAM Roles for Service Accounts).

For each EKS cluster listed in `local.kube_teleport_agent_bootstrap` the
module creates:

- An IAM role with an OIDC trust policy scoped to the agent's Kubernetes
  service account (IRSA).
- A `teleport_provision_token` resource that authorises the IAM role to join
  the Teleport cluster.

The Terraform run does **not** deploy pods into Kubernetes. After `terraform
apply` completes, use the Helm chart to deploy the actual agent workload (see
below).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

## Deploying the Helm chart

After Terraform has created the IAM roles and join tokens, deploy the
`teleport-kube-agent` Helm chart into each EKS cluster. The chart is published
by Teleport at `https://charts.releases.teleport.dev`.

```bash
helm repo add teleport https://charts.releases.teleport.dev
helm repo update

# Replace the placeholder values with the Terraform outputs.
helm install teleport-agent teleport/teleport-kube-agent \
  --namespace teleport-agent \
  --create-namespace \
  --set roles="kube\,app\,db\,discovery" \
  --set proxyAddr="teleport.example.com:443" \
  --set authToken="" \
  --set joinParams.method="iam" \
  --set joinParams.tokenName="teleport-my-eks-cluster-1-token" \
  --set kubeClusterName="my-eks-cluster-1" \
  --set serviceAccount.name="teleport-agent" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="<ROLE_ARN from terraform output>"
```

Repeat for each cluster, adjusting `kubeClusterName`, `joinParams.tokenName`,
the role ARN annotation, and the `roles` value to match the services you
enabled in the bootstrap map.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS region where the EKS clusters reside | `us-east-1` |
| `teleport_auth_server` | Address of the Teleport Auth/Proxy server | _required_ |
| `teleport_agent_namespace` | Kubernetes namespace for agent pods | `teleport-agent` |
| `teleport_service_account_name` | Kubernetes service account name | `teleport-agent` |

## Outputs

| Name | Description |
|------|-------------|
| `teleport_agent_role_arns` | Map of cluster name to IAM role ARN |
| `teleport_join_token_names` | Map of cluster name to Teleport join token name |
