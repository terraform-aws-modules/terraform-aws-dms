provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  name   = "dms-example-${replace(basename(path.cwd), "_", "-")}"

  db_name     = "example"
  db_username = "example"

  # aws dms describe-event-categories
  replication_instance_event_categories = ["failure", "creation", "deletion", "maintenance", "failover", "low storage", "configuration change"]
  replication_task_event_categories     = ["failure", "state change", "creation", "deletion", "configuration change"]

  bucket_postfix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = {
    Example     = local.name
    Environment = "dev"
  }
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}d"] # careful on which AZs support DMS VPC endpoint
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  create_database_subnet_group = true
  enable_nat_gateway           = false # not required, using private VPC endpoint
  single_nat_gateway           = true
  map_public_ip_on_launch      = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60
  flow_log_log_format                  = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"

  enable_dhcp_options      = true
  enable_dns_hostnames     = true
  dhcp_options_domain_name = data.aws_region.current.name == "us-east-1" ? "ec2.internal" : "${data.aws_region.current.name}.compute.internal"

  tags = local.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoint_security_group.security_group_id]

  endpoints = {
    dms = {
      service             = "dms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.database_subnets
      tags                = { Name = "dms-vpc-endpoint" }
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.database_route_table_ids])
      tags            = { Name = "s3-vpc-endpoint" }
    }
  }

  tags = local.tags
}

module "vpc_endpoint_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-vpc-endpoint"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "VPC Endpoints HTTPs for the VPC CIDR"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

  egress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules       = ["all-all"]

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  # Creates multiple
  for_each = {
    postgresql-source    = ["postgresql-tcp"]
    mysql-destination    = ["mysql-tcp"]
    replication-instance = ["postgresql-tcp", "mysql-tcp"]
    kafka-destination    = ["kafka-broker-tcp"]
  }

  name        = "${local.name}-${each.key}"
  description = "Security group for ${each.key}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = module.vpc.database_subnets_cidr_blocks
  ingress_rules       = each.value

  egress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules       = ["all-all"]

  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "postgresql" {
  name   = "${local.name}-postgresql"
  family = "aurora-postgresql11"

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
  version = "~> 6.0"

  # Creates multiple
  for_each = {
    postgresql-source = {
      engine                          = "aurora-postgresql"
      engine_version                  = "11.12"
      enabled_cloudwatch_logs_exports = ["postgresql"]
    },
    mysql-destination = {
      engine                          = "aurora-mysql"
      engine_version                  = "5.7.mysql_aurora.2.07.5"
      enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]
    }
  }

  name              = "${local.name}-${each.key}"
  database_name     = local.db_name
  master_username   = local.db_username
  apply_immediately = true

  engine                          = each.value.engine
  engine_version                  = each.value.engine_version
  instance_class                  = "db.t3.medium"
  instances                       = { 1 = {}, 2 = {} }
  storage_encrypted               = true
  skip_final_snapshot             = true
  db_cluster_parameter_group_name = each.key == "postgresql-source" ? aws_rds_cluster_parameter_group.postgresql.id : null

  enabled_cloudwatch_logs_exports = each.value.enabled_cloudwatch_logs_exports
  monitoring_interval             = 60
  create_monitoring_role          = true

  vpc_id                 = module.vpc.vpc_id
  subnets                = module.vpc.database_subnets
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_db_subnet_group = false
  create_security_group  = false
  vpc_security_group_ids = [module.security_group[each.key].security_group_id]

  tags = local.tags
}

resource "aws_sns_topic" "example" {
  name              = local.name
  kms_master_key_id = "alias/aws/sns"

  tags = local.tags
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 2.0"

  bucket = "${local.name}-s3-${local.bucket_postfix}"

  attach_deny_insecure_transport_policy = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_bucket_object" "hr_data" {
  bucket                 = module.s3_bucket.s3_bucket_id
  key                    = "sourcedata/hr/employee/LOAD0001.csv"
  source                 = "data/hr.csv"
  etag                   = filemd5("data/hr.csv")
  server_side_encryption = "AES256"

  tags = local.tags
}

resource "aws_iam_role" "s3_role" {
  name        = "${local.name}-s3"
  description = "Role used to migrate data from S3 via DMS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DMSAssume"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.${data.aws_partition.current.dns_suffix}"
        }
      },
    ]
  })

  inline_policy {
    name = "${local.name}-s3"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DMSRead"
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = "${module.s3_bucket.s3_bucket_arn}/*"
        },
        {
          Sid      = "DMSList"
          Action   = ["s3:ListBucket"]
          Effect   = "Allow"
          Resource = module.s3_bucket.s3_bucket_arn
        },
      ]
    })
  }

  tags = local.tags
}

# # TODO - coming soon after additional attributes are added
# module "msk_cluster" {
#   source  = "clowdhaus/msk-kafka-cluster/aws"
#   version = "~> 1.0"

#   name                   = local.name
#   kafka_version          = "2.8.0"
#   number_of_broker_nodes = 3

#   broker_node_client_subnets  = module.vpc.private_subnets
#   broker_node_ebs_volume_size = 20
#   broker_node_instance_type   = "kafka.t3.small"
#   broker_node_security_groups = [module.security_group.security_group_id]

#   configuration_name        = "${local.name}-configuration"
#   configuration_description = "Complete ${local.name} configuration"
#   configuration_server_properties = {
#     "auto.create.topics.enable" = true
#     "delete.topic.enable"       = true
#   }

#   tags = local.tags
# }

################################################################################
# DMS Module
################################################################################

module "dms_disabled" {
  source = "../.."

  create = false
}

module "dms_default" {
  source = "../.."

  # Note - if enabled, this will by default only create
  # - DMS necessary IAM roles
  # - Subnet group
  # - Replication instance
  create = false # not enabling by default to avoid messing with the IAM roles

  # Subnet group
  repl_subnet_group_name        = local.name
  repl_subnet_group_description = "DMS Subnet group for ${local.name}"
  repl_subnet_group_subnet_ids  = module.vpc.database_subnets

  # Instance
  repl_instance_class = "dms.t3.large"
  repl_instance_id    = local.name

  tags = local.tags
}

module "dms_aurora_postgresql_aurora_mysql" {
  source = "../.."

  # Subnet group
  repl_subnet_group_name        = local.name
  repl_subnet_group_description = "DMS Subnet group for ${local.name}"
  repl_subnet_group_subnet_ids  = module.vpc.database_subnets

  # Instance
  repl_instance_allocated_storage            = 64
  repl_instance_auto_minor_version_upgrade   = true
  repl_instance_allow_major_version_upgrade  = true
  repl_instance_apply_immediately            = true
  repl_instance_engine_version               = "3.4.5"
  repl_instance_multi_az                     = true
  repl_instance_preferred_maintenance_window = "sun:10:30-sun:14:30"
  repl_instance_publicly_accessible          = false
  repl_instance_class                        = "dms.t3.large"
  repl_instance_id                           = local.name
  repl_instance_vpc_security_group_ids       = [module.security_group["replication-instance"].security_group_id]

  endpoints = {
    s3-source = {
      endpoint_id   = "${local.name}-s3-source"
      endpoint_type = "source"
      engine_name   = "s3"
      ssl_mode      = "none"

      s3_settings = {
        bucket_folder             = "sourcedata"
        bucket_name               = module.s3_bucket.s3_bucket_id
        data_format               = "csv"
        encryption_mode           = "SSE_S3"
        external_table_definition = file("configs/s3_table_definition.json")
        service_access_role_arn   = aws_iam_role.s3_role.arn
      }

      tags = { EndpointType = "s3-source" }
    }

    postgresql-destination = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-postgresql-destination"
      endpoint_type               = "target"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;"
      username                    = local.db_username
      password                    = module.rds_aurora["postgresql-source"].cluster_master_password
      port                        = 5432
      server_name                 = module.rds_aurora["postgresql-source"].cluster_endpoint
      ssl_mode                    = "none"
      tags                        = { EndpointType = "postgresql-destination" }
    }

    postgresql-source = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-postgresql-source"
      endpoint_type               = "source"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;"
      username                    = local.db_username
      password                    = module.rds_aurora["postgresql-source"].cluster_master_password
      port                        = 5432
      server_name                 = module.rds_aurora["postgresql-source"].cluster_endpoint
      ssl_mode                    = "none"
      tags                        = { EndpointType = "postgresql-source" }
    }

    mysql-destination = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-mysql-destination"
      endpoint_type               = "target"
      engine_name                 = "aurora"
      extra_connection_attributes = ""
      username                    = local.db_username
      password                    = module.rds_aurora["mysql-destination"].cluster_master_password
      port                        = 3306
      server_name                 = module.rds_aurora["mysql-destination"].cluster_endpoint
      ssl_mode                    = "none"
      tags                        = { EndpointType = "mysql-destination" }
    }

    mssql-destination = {
      database_name        = local.db_name
      endpoint_id          = "${local.name}-mssql-destination"
      endpoint_type        = "target"
      engine_name          = "sqlserver"
      username             = local.db_username
      password_secret_path = "path/to/secret/manager/secret"
      port                 = 1433
      server_name          = "existing-db.address.us-east-1.rds.amazonaws.com"
      ssl_mode             = "require"
      tags                 = { EndpointType = "mssql-destination" }
    }
  }

  replication_tasks = {
    s3_import = {
      replication_task_id = "${local.name}-s3-import"
      migration_type      = "full-load"
      table_mappings      = file("configs/table_mappings.json")
      source_endpoint_key = "s3-source"
      target_endpoint_key = "postgresql-destination"
      tags                = { Task = "S3-to-PostgreSQL" }
    }
    postgresql_mysql = {
      replication_task_id       = "${local.name}-postgresql-to-mysql"
      migration_type            = "full-load-and-cdc"
      replication_task_settings = file("configs/task_settings.json")
      table_mappings            = file("configs/table_mappings.json")
      source_endpoint_key       = "postgresql-source"
      target_endpoint_key       = "mysql-destination"
      tags                      = { Task = "PostgreSQL-to-MySQL" }
    }

    # # TODO - coming soon after additional attributes are added
    # kafka-destination = {
    #   endpoint_id   = "${local.name}-kafka-destination"
    #   endpoint_type = "target"
    #   engine_name   = "kafka"
    #   ssl_mode      = "none"

    #   kafka_settings = {
    #     broker = module.msk_cluster.bootstrap_brokers
    #     topic  = local.name
    #   }

    #   tags = { EndpointType = "kafka-destination" }
    # }
  }

  event_subscriptions = {
    # # Despite what the terraform docs say, this is not valid - you must supply a `source_type`
    # all = {
    #   name                             = "all-events"
    #   enabled                          = true
    #   instance_event_subscription_keys = [local.name]
    #   task_event_subscription_keys     = ["postgresql_mysql"]
    #   event_categories                 = distinct(concat(local.replication_instance_event_categories, local.replication_task_event_categories))
    #   sns_topic_arn                    = aws_sns_topic.example.arn
    # },
    instance = {
      name                             = "instance-events"
      enabled                          = true
      instance_event_subscription_keys = [local.name]
      source_type                      = "replication-instance"
      event_categories                 = local.replication_instance_event_categories
      sns_topic_arn                    = aws_sns_topic.example.arn
    }
    task = {
      name                         = "task-events"
      enabled                      = true
      task_event_subscription_keys = ["s3_import", "postgresql_mysql"]
      source_type                  = "replication-task"
      event_categories             = local.replication_task_event_categories
      sns_topic_arn                = aws_sns_topic.example.arn
    }
  }

  # # Not applicable in this example but demonstrating its use
  # certificates = {
  #   source = {
  #     certificate_id  = "${local.name}-source"
  #     certificate_pem = "..."
  #   }
  #   destination = {
  #     certificate_id  = "${local.name}-destination"
  #     certificate_pem = "..."
  #   }
  # }

  tags = local.tags
}
