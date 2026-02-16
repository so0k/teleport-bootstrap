resource "aws_iam_role" "node" {
  name               = "${var.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.id
  policy_arn = var.ssm_policy_arn
}

resource "aws_iam_role_policy_attachment" "additional_attached_policy_arns" {
  for_each   = var.additional_attached_policy_arns
  role       = aws_iam_role.node.id
  policy_arn = each.value
}

# inline parameter store
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html
data "aws_iam_policy_document" "node_parameterstore" {
  statement {
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath",
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    # note: this overlaps with
    # arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore includes:
    # "Resource": "*"
    # "Actions": [
    #       "ssm:GetParameter",
    #       "ssm:GetParameters"
    # ]
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    effect = "Allow"
    resources = [
      aws_ssm_parameter.teleport_etc.arn,
    ]
  }
}

resource "aws_iam_role_policy" "node_parameterstore" {
  name   = "${var.name_prefix}-parameterstore-policy"
  policy = data.aws_iam_policy_document.node_parameterstore.json
  role   = aws_iam_role.node.name
}

# inline datadog api key
data "aws_iam_policy_document" "node_datadog_api_key" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.datadog_api_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "node_datadog_api_key" {
  name   = "${var.name_prefix}-datadog-api-key-policy"
  policy = data.aws_iam_policy_document.node_datadog_api_key.json
  role   = aws_iam_role.node.name
}

# inline teleport IAM Join requirements
# https://goteleport.com/docs/agents/join-services-to-your-cluster/aws-iam/#step-14-set-up-aws-iam-credentials
data "aws_iam_policy_document" "node_teleport_iam_join" {
  statement {
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "node_teleport_iam_join" {
  name   = "${var.name_prefix}-teleport-iam-join-policy"
  policy = data.aws_iam_policy_document.node_teleport_iam_join.json
  role   = aws_iam_role.node.name
}

resource "aws_iam_role_policy" "teleport_managed_access" {
  count = var.teleport_managed_identities_enabled ? 1 : 0

  name   = "${var.name_prefix}-teleport-managed-access"
  policy = one(data.aws_iam_policy_document.teleport_managed_access[*].json)
  role   = aws_iam_role.node.name
}

data "aws_iam_policy_document" "teleport_managed_access" {
  count = var.teleport_managed_identities_enabled ? 1 : 0

  statement {
    actions = [
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-role",
    ]
  }
}

resource "aws_iam_role_policy" "elasticache_autodiscovery" {
  count = var.elasticache_autodiscovery_policy_enabled ? 1 : 0

  name   = "${var.name_prefix}-elasticache-autodiscovery"
  policy = one(data.aws_iam_policy_document.elasticache_autodiscovery[*].json)
  role   = aws_iam_role.node.name
}

data "aws_iam_policy_document" "elasticache_autodiscovery" {
  count = var.elasticache_autodiscovery_policy_enabled ? 1 : 0

  # https://goteleport.com/docs/database-access/reference/aws/#elasticachememorydb-auto-discovery
  statement {
    sid = "ElasticacheDiscover"
    actions = [
      "elasticache:ListTagsForResource",
      "elasticache:DescribeReplicationGroups",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeCacheSubnetGroups",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "elasticache_access" {
  count = var.elasticache_access_policy_enabled ? 1 : 0

  name   = "${var.name_prefix}-elasticache-access"
  policy = one(data.aws_iam_policy_document.elasticache_access[*].json)
  role   = aws_iam_role.node.name
}

data "aws_iam_policy_document" "elasticache_access" {
  count = var.elasticache_access_policy_enabled ? 1 : 0

  # https://goteleport.com/docs/database-access/reference/aws/#elasticachememorydb-auto-discovery
  statement {
    sid = "ElasticacheAccess"
    actions = [
      "elasticache:DescribeUsers",
      "elasticache:Connect",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    sid = "ElasticachePasswordRotation"
    actions = [
      "elasticache:DescribeUsers",
      "elasticache:ModifyUser",
    ]
    resources = [
      "*",
    ]
  }
}

# inline additional
data "aws_iam_policy_document" "additional_inline_policies" {
  for_each = { for k, v in var.additional_inline_policies :
    k => v
    if length(v.policy) > 0
  }

  dynamic "statement" {
    for_each = each.value.policy
    content {
      sid           = statement.key
      effect        = statement.value.effect
      actions       = statement.value.actions
      resources     = statement.value.resources
      not_resources = statement.value.not_resources

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "additional_inline_policies" {
  for_each = { for k, v in var.additional_inline_policies :
    k => v
    if length(v.policy) > 0
  }
  name   = "${var.name_prefix}-${each.key}-policy"
  policy = data.aws_iam_policy_document.additional_inline_policies[each.key].json
  role   = aws_iam_role.node.name
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name_prefix}-profile"
  role = aws_iam_role.node.name
  tags = var.tags
}
