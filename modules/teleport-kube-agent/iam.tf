################################################
#               shared resources               #
################################################
locals {
  iam_role_name = "${var.name_prefix}-role"
}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "sts_get_caller_identity" {
  statement {
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sts_get_caller_identity" {
  name   = "${var.name_prefix}-policy"
  policy = data.aws_iam_policy_document.sts_get_caller_identity.json
}

module "irsa" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version     = "~> 5.11.0"
  create_role = true
  role_name   = local.iam_role_name

  provider_urls = [
    data.aws_iam_openid_connect_provider.this.url,
  ]

  role_policy_arns = [
    aws_iam_policy.sts_get_caller_identity.arn
  ]

  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.teleport_agent_namespace}:${var.teleport_service_account_name}"]
}
