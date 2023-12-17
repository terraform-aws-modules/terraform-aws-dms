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

  # MSK
  sasl_scram_credentials = {
    username = local.name
    password = "password123!" # do better!
  }

  # aws dms describe-event-categories
  replication_instance_event_categories = ["failure", "creation", "deletion", "maintenance", "failover", "low storage", "configuration change"]
  replication_task_event_categories     = ["failure", "state change", "creation", "deletion", "configuration change"]

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-dms"
  }
}

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
  repl_subnet_group_subnet_ids  = module.vpc.private_subnets

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
  repl_subnet_group_subnet_ids  = module.vpc.private_subnets

  # Instance
  repl_instance_allocated_storage            = 64
  repl_instance_auto_minor_version_upgrade   = true
  repl_instance_allow_major_version_upgrade  = true
  repl_instance_apply_immediately            = true
  repl_instance_engine_version               = "3.5.2"
  repl_instance_multi_az                     = true
  repl_instance_preferred_maintenance_window = "sun:10:30-sun:14:30"
  repl_instance_publicly_accessible          = false
  repl_instance_class                        = "dms.t3.large"
  repl_instance_id                           = local.name
  repl_instance_vpc_security_group_ids       = [module.security_group["replication-instance"].security_group_id]

  # Access role
  create_access_iam_role = true
  access_secret_arns = [
    module.secrets_manager_postgresql.secret_arn,
    module.secrets_manager_mysql.secret_arn,
  ]
  access_source_s3_bucket_arns = [
    module.s3_bucket.s3_bucket_arn,
    "${module.s3_bucket.s3_bucket_arn}/*"
  ]

  # S3 Endpoints
  s3_endpoints = {
    s3-source = {
      endpoint_id   = "${local.name}-s3-source"
      endpoint_type = "source"
      engine_name   = "s3"

      bucket_folder               = "sourcedata"
      bucket_name                 = module.s3_bucket.s3_bucket_id
      data_format                 = "csv"
      ssl_mode                    = "none"
      encryption_mode             = "SSE_S3"
      extra_connection_attributes = ""
      external_table_definition   = file("configs/s3_table_definition.json")
      tags                        = { EndpointType = "s3-source" }
    }
  }

  # Endpoints
  endpoints = {
    postgresql-destination = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-postgresql-destination"
      endpoint_type               = "target"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;secretsManagerEndpointOverride=${module.vpc_endpoints.endpoints["secretsmanager"]["dns_entry"][0]["dns_name"]}"
      secrets_manager_arn         = module.secrets_manager_postgresql.secret_arn

      tags = { EndpointType = "postgresql-destination" }
    }

    postgresql-source = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-postgresql-source"
      endpoint_type               = "source"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;secretsManagerEndpointOverride=${module.vpc_endpoints.endpoints["secretsmanager"]["dns_entry"][0]["dns_name"]}"
      secrets_manager_arn         = module.secrets_manager_postgresql.secret_arn

      postgres_settings = {
        capture_ddls     = true
        heartbeat_enable = false
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

    kafka-destination = {
      endpoint_id   = "${local.name}-kafka-destination"
      endpoint_type = "target"
      engine_name   = "kafka"

      kafka_settings = {
        # this https://github.com/hashicorp/terraform/issues/4149 requires the MSK cluster exists before applying
        broker                  = join(",", module.msk_cluster.bootstrap_brokers)
        include_control_details = true
        include_null_and_empty  = true
        message_format          = "json"
        sasl_password           = local.sasl_scram_credentials["password"]
        sasl_username           = local.sasl_scram_credentials["username"]
        security_protocol       = "sasl-ssl"
        topic                   = "kafka-destination-topic"
      }

      tags = { EndpointType = "kakfa-destination" }
    }
  }

  replication_tasks = {
    s3_import = {
      replication_task_id       = "${local.name}-s3-import"
      migration_type            = "full-load"
      replication_task_settings = file("configs/task_settings.json")
      table_mappings            = file("configs/table_mappings.json")
      source_endpoint_key       = "s3-source"
      target_endpoint_key       = "postgresql-destination"
      tags                      = { Task = "S3-to-PostgreSQL" }
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
    postgresql_kafka = {
      replication_task_id       = "${local.name}-postgresql-to-kafka"
      migration_type            = "full-load-and-cdc"
      replication_task_settings = file("configs/task_settings.json")
      table_mappings            = file("configs/kafka_mappings.json")
      source_endpoint_key       = "postgresql-source"
      target_endpoint_key       = "kafka-destination"
      tags                      = { Task = "PostgreSQL-to-Kafka" }
    }
  }

  event_subscriptions = {
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
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.database_route_table_ids])
      tags            = { Name = "s3-vpc-endpoint" }
    }
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
    postgresql-source    = ["postgresql-tcp"]
    mysql-destination    = ["mysql-tcp"]
    replication-instance = ["postgresql-tcp", "mysql-tcp", "kafka-broker-sasl-scram-tcp"]
    kafka-destination    = ["kafka-broker-sasl-scram-tcp"]
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

resource "aws_sns_topic" "example" {
  name = local.name

  tags = local.tags
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.1"

  bucket_prefix = local.name

  attach_deny_insecure_transport_policy = false
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_object" "hr_data" {
  bucket                 = module.s3_bucket.s3_bucket_id
  key                    = "sourcedata/hr/employee/LOAD0001.csv"
  source                 = "data/hr.csv"
  etag                   = filemd5("data/hr.csv")
  server_side_encryption = "AES256"

  tags = local.tags
}

module "msk_cluster" {
  source  = "terraform-aws-modules/msk-kafka-cluster/aws"
  version = "~> 2.0"

  name                   = local.name
  kafka_version          = "3.4.0"
  number_of_broker_nodes = 3

  broker_node_client_subnets = module.vpc.private_subnets
  broker_node_storage_info = {
    ebs_storage_info = { volume_size = 20 }
  }
  broker_node_instance_type   = "kafka.t3.small"
  broker_node_security_groups = [module.security_group["kafka-destination"].security_group_id]

  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true

  configuration_name        = "${local.name}-configuration"
  configuration_description = "Complete ${local.name} configuration"
  configuration_server_properties = {
    "auto.create.topics.enable" = true
    "delete.topic.enable"       = true
  }

  client_authentication = {
    sasl = { scram = true }
  }
  create_scram_secret_association          = true
  scram_secret_association_secret_arn_list = [module.secrets_manager_msk.secret_arn]

  tags = local.tags
}

module "secrets_manager_msk" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name_prefix = "AmazonMSK_${local.name}-"
  description = "Secret for ${local.name}"

  # Secret
  recovery_window_in_days = 0
  secret_string           = jsonencode(local.sasl_scram_credentials)
  kms_key_id              = aws_kms_key.this.id

  # Policy
  create_policy       = true
  block_public_policy = true
  policy_statements = {
    read = {
      sid = "AWSKafkaResourcePolicy"
      principals = [{
        type        = "Service"
        identifiers = ["kafka.amazonaws.com"]
      }]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }

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
