variable "name_prefix" {
  description = "name prefix for resources created"
  type        = string
}

variable "ami_id" {
  description = "AMI for teleport agent instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets to deploy"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups to attach to instance"
  type        = list(string)
  default     = []
}

variable "hour_to_scale_up" {
  description = "UTC hour for ASG scheduled scale up (MON-FRI)"
  type        = number
  default     = null
}

variable "hour_to_scale_down" {
  description = "UTC hour for ASG scheduled scale down (every day)"
  type        = string
  default     = null
}

variable "asg_min" {
  description = "ASG minimum size"
  type        = number
  default     = 0
}

variable "asg_max" {
  description = "ASG maximum size"
  type        = number
  default     = 1
}

variable "asg_scale_up_desired" {
  description = "ASG desired size at scale_up"
  type        = number
  default     = 1
}

variable "asg_scale_down_desired" {
  description = "ASG desired size at scale_down"
  type        = number
  default     = 0
}

variable "instance_types" {
  description = "EC2 Instance types (only ARM supported)"
  type        = list(string)
  default     = ["t4g.micro"]
}

variable "encryption" {
  description = "Whether or not to encrypt the EBS volume"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "Will use the provided KMS key ID to encrypt the EBS volume. Uses the default KMS key if none provided"
  type        = string
  default     = null
}

variable "ebs_root_volume_size" {
  description = "Size of the EBS root volume in GB"
  type        = number
  default     = 4

  validation {
    condition     = var.ebs_root_volume_size >= 4
    error_message = "The root volume size must be at least 4 or more"
  }
}

variable "ssm_policy_arn" {
  description = "SSM Policy to be attached to instance profile"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "ssm_tier" {
  description = "If the requests fulfills the criteria for using 'Advanced', in this case content > 4KB, 'Intelligent-Tier' will automatically request for 'Advanced' tier. Note this cannot be downgraded to 'Standard' because of param size truncation. See https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.ssm_tier)
    error_message = "ssm_tier accepts 'Intelligent-Tiering', 'Standard' or 'Advanced'"
  }
}

variable "tags" {
  description = "Tags to apply to resources created within the module"
  type        = map(string)
  default     = {}
}

variable "userdata_gzip" {
  description = "Whether or not to gzip the userdata script"
  type        = bool
  default     = true
}

variable "bootstrap_commands" {
  description = "List of commands to run on instance boot. Use with care, consider reviewing the Packer AMI scripts."
  type        = list(string)
  default     = []
}

variable "use_spot_instances" {
  description = "Whether to use spot or on-demand EC2 instances"
  type        = bool
  default     = false
}

## datadog agent config

variable "datadog_api_key_arn" {
  description = "ARN to AWS Secrets Manager secret containing the DataDog API Key"
  type        = string
}

variable "datadog_host_tags" {
  description = "DataDog Agent Host Tags in in env:prod,foo:bar format"
  type        = string
}

## teleport agent config

variable "teleport_auth_server" {
  description = "Teleport Auth Server address (e.g. example.teleport.sh:443)"
  type        = string

  validation {
    condition     = can(regex("^.+:\\d+$", var.teleport_auth_server))
    error_message = "teleport_auth_server must include host and port (e.g. example.teleport.sh:443)"
  }
}

variable "teleport_create_join_token" {
  description = "Whether or not to create a join token for the agent pool. (disable for e2e)"
  type        = bool
  default     = true
}

variable "teleport_ssh_service" {
  description = "Teleport SSH Service. [docs](https://goteleport.com/docs/reference/config/#ssh-service)"
  type = object({
    enabled = optional(bool, true)
    # See the explanation of labels in the "Labels" page
    # (https://goteleport.com/docs/setup/admin/labels).
    labels = optional(map(string), {})
    # List of the commands to periodically execute. Their output will be used
    # as node labels.
    commands = optional(list(object({
      name    = string
      command = list(string)
      period  = string
    })), [])
  })
  default = {}
}

variable "teleport_app_service" {
  description = "Teleport App Service. [docs](https://goteleport.com/docs/reference/config/#application-service)"
  type = object({
    enabled = optional(bool, false)
    # Teleport contains a small debug app that can be used to make sure the
    # Application Service is working correctly. The app outputs JWTs so it can
    # be useful when extending your application.
    debug_app = optional(bool, false)
    # Matchers for dynamic application resources
    #
    # All application resources have a predefined "teleport.dev/origin" label with
    # one of the following values:
    # "dynamic": application resources created via an Auth Service API
    # client like `tctl` or the Teleport Terraform provider
    # "config": application resources defined in the "apps" array below
    resources = optional(list(object({
      labels = map(string)
      })), [{
      labels = {
        "*" = "*"
      }
    }])
    apps = list(object({
      name = string
      # Optional: For access to cloud provider APIs, specify the cloud
      # provider. Allowed values are "AWS", "Azure", and "GCP".
      cloud = optional(string)
      # URI and Port of Application.
      uri = string
      # Optionally skip TLS verification. default false
      insecure_skip_verify = optional(bool)
      # Optional Public Addr
      public_addr = optional(string)
      # Optional Label: These can be used in combination with RBAC rules
      # to limit access to applications
      labels = optional(map(string), {})
      # Optional Dynamic Labels
      commands = optional(list(object({
        name    = string
        command = list(string)
        period  = string
      })), [])
      ## Optional list of rewrite rules to apply to requests and responses
      rewrite = optional(list(object({
        ## Optional simple rewriting of Location header
        ## Rewrite the "Location" header on redirect responses replacing the
        ## host with the public address of this application.
        redirect = optional(list(string))
        ## Optional list of extra headers to inject in to requests.
        #   For example: ["Host: jenkins.example.com"]
        headers = optional(list(string))
        ## Optional rewrite to remove parts of the JWT token.
        ## Can be one of three options:
        ## - roles-and-traits: include both roles and traits in the JWT token
        ## - roles: include only roles in the JWT token
        ## - traits: include only traits in the JWT token
        ## - none: include neither roles nor traits in the JWT token
        ## Default: roles-and-traits
        jwt_claims = optional(string)
      })))
    }))
  })
  default = {
    apps = []
  }
}

variable "teleport_db_service" {
  description = "Teleport Database Service. [docs](https://goteleport.com/docs/reference/config/#database-service)"
  type = object({
    # Enables the Database Service.
    enabled = optional(bool, false)
    # Matchers for database resources created with "tctl create" command or by the
    # discovery service.
    resources = optional(list(object({
      # See "Database labels reference" (https://goteleport.com/docs/database-access/reference/labels/)
      # to learn more on database labels.
      labels = map(string)
      # Optional AWS role that the Database Service will assume to access the
      # databases.
      aws = optional(object({
        assume_role_arn = string
        # Optional AWS external ID that the Database Service will use to assume
        # a role in an external AWS account.
        external_id = optional(string)
      }))
      })), [{
      labels = {
        "*" = "*"
      }
    }])
    # Matchers for registering AWS-hosted databases.
    aws = optional(list(object({
      # Database types. Valid options are:
      # 'rds' - discovers and registers AWS RDS and Aurora databases.
      # 'rdsproxy' - discovers and registers AWS RDS Proxy databases.
      # 'redshift' - discovers and registers AWS Redshift databases.
      # 'redshift-serverless' - discovers and registers AWS Redshift Serverless databases.
      # 'elasticache' - discovers and registers AWS ElastiCache Redis databases.
      # 'memorydb' - discovers and registers AWS MemoryDB Redis databases.
      # 'opensearch' - discovers and registers AWS OpenSearch Redis databases.
      types = list(string)
      # AWS regions to register databases from.
      regions = list(string)
      # AWS resource tags to match when registering databases.
      tags = optional(map(string), {
        "*" = "*"
      })
      # Optional AWS role that the Database Service will assume to discover
      # and register AWS-hosted databases.
      # Discovered databases are also accessed by the Database Service via
      # this role.
      assume_role_arn = optional(string)
      # Optional AWS external ID that the Database Service will use to assume
      # a role in an external AWS account.
      external_id = optional(string)
    })))
    # Lists statically registered databases proxied by this agent.
    databases = optional(list(object({
      name        = string # Name of the database proxy instance, used to reference in CLI.
      description = string # Free-form description of the database proxy instance.
      protocol    = string # Database protocol. Can be: "postgres", "mysql", "mongodb", "oracle", "clickhouse", "clickhouse-http", "cockroachdb", "redis", "snowflake", "sqlserver", "cassandra", "elasticsearch", or "dynamodb"
      uri         = string # Database connection endpoint. Must be reachable from Database Service.
      # Optional TLS configuration.
      tls = optional(object({
        # TLS verification mode. Valid options are:
        # 'verify-full' - performs full certificate validation (default).
        # 'verify-ca' - the same as `verify-full`, but skips the server name validation.
        # 'insecure' - accepts any certificate provided by database (not recommended).
        mode = string
        # Optional database DNS server name. It allows to override the DNS name on
        # a client certificate when connecting to a database.
        # Use only with 'verify-full' mode.
        server_name = optional(string)
        # Optional path to the CA used to validate the database certificate.
        ca_cert_file = optional(string)
      }))
      # MySQL only options.
      mysql = optional(object({
        # The default MySQL server version reported by Teleport Proxy.
        # When this option is set the Database Agent doesn't try to check the MySQL server version.
        server_version = string
      }))
      # Optional admin user configuration for Automatic User Provisioning.
      admin_user = optional(object({
        name             = string           # Name of the admin user.
        default_database = optional(string) #  Optional default database the admin user logs into. See individual guides for default value.
      }))
      # Optional AWS configuration for AWS hosted databases. AWS region- and
      # service-specific configurations can usually be auto-detected from the
      # endpoint.
      aws = optional(object({
        region          = string           # Region the database is deployed in.
        assume_role_arn = optional(string) # Optional AWS role that the Database Service will assume
        external_id     = optional(string) # Optional AWS external ID that the Database Service will use to assume a role in an external AWS account.
        # Redshift-specific configuration.
        redshift = optional(object({
          cluster_id = string # Redshift cluster identifier.
        }))
        # RDS-specific configuration.
        rds = optional(object({
          instance_id = optional(string) # RDS instance identifier.
          cluster_id  = optional(string) # RDS Aurora cluster identifier.
        }))
        # ElastiCache-specific configuration.
        elasticache = optional(object({
          replication_group_id = string # ElastiCache replication group identifier.
        }))
        # MemoryDB-specific configuration.
        memorydb = optional(object({
          cluster_name = string # MemoryDB cluster name.
        }))
        # Optional AWS Secrets Manager configuration for managing ElastiCache
        # or MemoryDB users.
        #
        # IMPORTANT: please make sure databases sharing the same Teleport-managed
        # users have the same secret_store configuration. The configuration
        # should also be consistent across all Database Services in High
        # Availability (HA) mode.
        secret_store = optional(object({
          key_prefix = optional(string, "teleport/") # Prefix to all secrets created by the service.
          # KMS Key ID used for secret encryption and description. If not
          # specified, Secrets Manager uses AWS managed key 'aws/secretsmanager'
          # by default.
          kms_key_id = optional(string)
        }))
      }))
      static_labels = optional(map(string), {})
      dynamic_labels = optional(list(object({
        name    = string
        command = list(string)
        period  = string
      })), [])
    })))
  })
  default = {}
}

variable "teleport_discovery_service" {
  description = "Teleport Discovery Service. [docs](https://goteleport.com/docs/reference/config/#discovery-service)"
  type = object({
    # Enables the Discovery Service.
    enabled = optional(bool, false)
    # discovery_group is used to group discovered resources into different
    # sets. This is useful when you have multiple Teleport Discovery services
    # running in the same cluster but polling different cloud providers or cloud
    # accounts. It prevents discovered services from colliding in Teleport when
    # managing discovered resources.
    discovery_group = string
    aws = list(object({
      # AWS resource types. Valid options are:
      # 'ec2' - discovers and registers AWS EC2 instances.
      #       - ref: https://goteleport.com/docs/server-access/guides/ec2-discovery/#step-27-define-an-iam-policy
      # 'eks' - discovers and registers AWS EKS clusters.
      #       - ref: https://goteleport.com/docs/kubernetes-access/discovery/aws/#step-13-set-up-aws-iam-credentials
      #       - ref: https://goteleport.com/docs/kubernetes-access/discovery/aws/#configure-the-teleport-kubernetes-and-discovery-services
      # 'rds' - discovers and registers AWS RDS and Aurora databases.
      #       - ref: https://goteleport.com/docs/database-access/guides/rds/#step-36-create-iam-policies-for-teleport
      #       - ref: https://goteleport.com/docs/database-access/guides/aws-discovery/#step-34-bootstrap-iam-permissions
      # 'rdsproxy' - discovers and registers AWS RDS Proxy databases.
      # 'redshift' - discovers and registers AWS Redshift databases.
      # 'redshift-serverless' - discovers and registers AWS Redshift Serverless databases.
      # 'elasticache' - discovers and registers AWS ElastiCache Redis databases.
      # 'memorydb' - discovers and registers AWS MemoryDB Redis databases.
      # 'opensearch' - discovers and registers AWS OpenSearch Redis databases.
      types = list(string)
      # AWS regions to search for resources from
      regions = list(string)
      # AWS resource tags to match when registering resources
      # Optional section: Defaults to "*":"*"
      tags = optional(map(string), {
        "*" = "*"
      })
      # Optional AWS role that the Discovery Service will assume to discover
      # and register AWS-hosted databases and EKS clusters.
      assume_role_arn = optional(string)
      # Optional AWS external ID that the Discovery Service will use to assume
      # a role in an external AWS account.
      external_id = optional(string)
      # Optional section: install is used to provide parameters to the AWS SSM document.
      # If the install section isn't provided, the below defaults are used.
      # Only applicable for EC2 discovery.
      install = optional(object({
        join_params = optional(object({
          # token_name is the name of the Teleport invite token to use.
          token_name = optional(string, "aws-discovery-iam-token")
        }))
        # script_name is the name of the Teleport install script to use.
        script_name = optional(string, "default-installer")
      }))
      # Optional section: ssm is used to configure which AWS SSM document to use
      ssm = optional(object({
        document_name = optional(string, "TeleportDiscoveryInstaller")
      }))
    }))
  })
  default = {
    discovery_group = "default"
    aws             = []
  }
}

variable "teleport_managed_identities_enabled" {
  description = "Whether to create IAM policy for Teleport agent to self-manage its role policy for access to discovered services. Ref: https://goteleport.com/docs/database-access/reference/aws/#teleport-managed-iam-identities-for-elasticachememorydb-access"
  type        = bool
  default     = false
}

variable "elasticache_autodiscovery_policy_enabled" {
  description = "Grant agent role with elasticache auto-discovery related IAM permissions. https://goteleport.com/docs/database-access/reference/aws/#elasticachememorydb-auto-discovery"
  type        = bool
  default     = false
}

variable "elasticache_access_policy_enabled" {
  description = "Grant agent role with elasticache access related IAM permissions. https://goteleport.com/docs/database-access/reference/aws/#manage-iam-identities-yourself-for-elasticachememorydb-access"
  type        = bool
  default     = false
}

# note:
# existing attached policies hardcoded in module:
# - AmazonSSMManagedInstanceCore: to manage node through System Manager
variable "additional_attached_policy_arns" {
  description = "Additional policy ARNs to attach to Instance role"
  type        = map(string)
  default     = {}
}

# note:
# existing inline policies
# - SSM ParameterStore teleport-etc/contents: To read Teleport config from SSM Parameter Store
# - DatadogAgent API Key: to read DataDog API key from Secrets Manager
variable "additional_inline_policies" {
  description = "Additional inline policies for Instance role"
  type = map(object({
    policy = map(object({
      effect        = optional(string, "Allow")
      actions       = list(string)
      resources     = optional(list(string))
      not_resources = optional(list(string))
      conditions = optional(list(object({
        test     = string
        variable = string
        values   = list(string)
      })), [])
    }))
  }))
  default = {}
}

variable "log_level" {
  description = "Teleport log level. Accepts DEBUG, INFO, WARN, ERROR"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], upper(var.log_level))
    error_message = "Should be one of 'DEBUG', 'INFO', 'WARN' or 'ERROR'"
  }
}
