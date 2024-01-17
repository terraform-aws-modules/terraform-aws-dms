provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region = "us-east-1"
  name   = "dms-ex-${basename(path.cwd)}"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  db_name     = "example"
  db_username = "example"
  db_password = "password123!" # do better!

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-dms"
  }
}

################################################################################
# DMS Module
################################################################################

module "dms_aurora_postgresql_aurora_mysql" {
  source = "../.."

  # Subnet group
  repl_subnet_group_name        = local.name
  repl_subnet_group_description = "DMS Subnet group for ${local.name}"
  repl_subnet_group_subnet_ids  = module.vpc.private_subnets

  # Instance
  create_repl_instance = false

  # Access role
  create_access_iam_role = true
  access_secret_arns = [
    module.secrets_manager_postgresql.secret_arn,
    module.secrets_manager_mysql.secret_arn,
  ]

  # Endpoints
  endpoints = {
    postgresql-source = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-postgresql-source"
      endpoint_type               = "source"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;secretsManagerEndpointOverride=${module.vpc_endpoints.endpoints["secretsmanager"]["dns_entry"][0]["dns_name"]}"
      secrets_manager_arn         = module.secrets_manager_postgresql.secret_arn

      postgres_settings = {
        capture_ddls        = false
        heartbeat_enable    = true
        heartbeat_frequency = 1
      }

      tags = { EndpointType = "postgresql-source" }
    }

    mysql-destination = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-mysql-destination"
      endpoint_type               = "target"
      engine_name                 = "aurora"
      extra_connection_attributes = "secretsManagerEndpointOverride=${module.vpc_endpoints.endpoints["secretsmanager"]["dns_entry"][0]["dns_name"]}"
      secrets_manager_arn         = module.secrets_manager_mysql.secret_arn

      tags = { EndpointType = "mysql-destination" }
    }
  }

  replication_tasks = {
    postgresql_mysql = {
      replication_task_id       = "postgresql-to-mysql"
      migration_type            = "full-load-and-cdc"
      replication_task_settings = file("configs/task_settings.json")
      table_mappings            = file("configs/table_mappings.json")
      source_endpoint_key       = "postgresql-source"
      target_endpoint_key       = "mysql-destination"

      serverless_config = {
        max_capacity_units     = 2
        min_capacity_units     = 1
        multi_az               = true
        vpc_security_group_ids = [module.security_group["replication-configuration"].security_group_id]
      }

      tags = { Task = "PostgreSQL-to-MySQL" }
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  enable_nat_gateway = true
  single_nat_gateway = true

  create_database_subnet_group = true

  tags = local.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id                     = module.vpc.vpc_id
  create_security_group      = true
  security_group_name_prefix = "${local.name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    secretsmanager = {
      service_name = "com.amazonaws.${local.region}.secretsmanager"
      subnet_ids   = module.vpc.private_subnets
    }
  }

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  # Creates multiple
  for_each = {
    postgresql-source         = ["postgresql-tcp"]
    mysql-destination         = ["mysql-tcp"]
    replication-configuration = ["postgresql-tcp", "mysql-tcp"]
  }

  name        = "${local.name}-${each.key}"
  description = "Security group for ${each.key}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_rules       = each.value

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]

  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "postgresql" {
  name   = "${local.name}-postgresql"
  family = "aurora-postgresql14"

  parameter {
    name         = "rds.logical_replication"
    value        = 1
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "wal_sender_timeout"
    value = 0
  }

  tags = local.tags
}

module "rds_aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 8.0"

  # Creates multiple
  for_each = {
    postgresql-source = {
      engine                          = "aurora-postgresql"
      engine_version                  = "14.7"
      enabled_cloudwatch_logs_exports = ["postgresql"]
    },
    mysql-destination = {
      engine                          = "aurora-mysql"
      engine_version                  = "8.0"
      enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]
    }
  }

  name                        = "${local.name}-${each.key}"
  database_name               = local.db_name
  master_username             = local.db_username
  master_password             = local.db_password
  manage_master_user_password = false
  apply_immediately           = true

  engine                          = each.value.engine
  engine_version                  = each.value.engine_version
  instance_class                  = "db.t3.medium"
  instances                       = { 1 = {}, 2 = {} }
  storage_encrypted               = true
  skip_final_snapshot             = true
  db_cluster_parameter_group_name = each.key == "postgresql-source" ? aws_rds_cluster_parameter_group.postgresql.id : null

  vpc_id                 = module.vpc.vpc_id
  subnets                = module.vpc.database_subnets
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_db_subnet_group = false
  create_security_group  = false
  vpc_security_group_ids = [module.security_group[each.key].security_group_id]

  tags = local.tags
}

resource "aws_kms_key" "this" {
  description         = "KMS CMK for ${local.name}"
  enable_key_rotation = true

  tags = local.tags
}

module "secrets_manager_postgresql" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix = "PostgreSQL-${local.name}-"
  description = "Secret for ${local.name}"

  # Secret
  recovery_window_in_days = 0
  secret_string = jsonencode(
    {
      username = local.db_username
      password = local.db_password
      port     = 5432
      host     = module.rds_aurora["postgresql-source"].cluster_endpoint
    }
  )
  kms_key_id = aws_kms_key.this.id

  tags = local.tags
}

module "secrets_manager_mysql" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix = "MySQL-${local.name}-"
  description = "Secret for ${local.name}"

  # Secret
  recovery_window_in_days = 0
  secret_string = jsonencode(
    {
      username = local.db_username
      password = local.db_password
      port     = 3306
      host     = module.rds_aurora["mysql-destination"].cluster_endpoint
    }
  )
  kms_key_id = aws_kms_key.this.id

  tags = local.tags
}
