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

  tags = {
    Example     = local.name
    Environment = "dev"
  }
}

data "aws_region" "current" {}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3"

  name = local.name
  cidr = "10.99.0.0/18"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}d"] # careful on which AZs support DMS VPC endpoint
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  create_database_subnet_group = true
  enable_nat_gateway           = false # not required, using private VPC endpoint
  single_nat_gateway           = false

  enable_dhcp_options      = true
  enable_dns_hostnames     = true
  dhcp_options_domain_name = data.aws_region.current.name == "us-east-1" ? "ec2.internal" : "${data.aws_region.current.name}.compute.internal"

  tags = local.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoint_security_group.security_group_id]

  endpoints = {
    dms = {
      service             = "dms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.database_subnets
      tags                = { Name = "dms-vpc-endpoint" }
    }
  }

  tags = local.tags
}

module "vpc_endpoint_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4"

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
  version = "~> 4"

  # Creates multiple
  for_each = {
    source               = ["postgresql-tcp"]
    destination          = ["mysql-tcp"]
    replication-instance = ["postgresql-tcp", "mysql-tcp"]
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

module "rds_aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 5"

  # Creates multiple
  for_each = {
    source = {
      engine         = "aurora-postgresql"
      engine_version = "11.12"
    },
    destination = {
      engine         = "aurora-mysql"
      engine_version = "5.7.mysql_aurora.2.07.5"
    }
  }

  name              = "${local.name}-${each.key}"
  database_name     = local.db_name
  username          = local.db_username
  apply_immediately = true

  engine              = each.value.engine
  engine_version      = each.value.engine_version
  replica_count       = 1
  instance_type       = "db.t3.medium"
  storage_encrypted   = false
  skip_final_snapshot = true

  vpc_id                 = module.vpc.vpc_id
  subnets                = module.vpc.database_subnets
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_security_group  = false
  vpc_security_group_ids = [module.security_group[each.key].security_group_id]

  tags = local.tags
}

resource "aws_sns_topic" "example" {
  name = local.name
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
    source = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-source"
      endpoint_type               = "source"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;"
      username                    = local.db_username
      password                    = module.rds_aurora["source"].rds_cluster_master_password
      port                        = 5432
      server_name                 = module.rds_aurora["source"].rds_cluster_endpoint
      ssl_mode                    = "none"
      tags                        = { EndpointType = "source" }
    }

    destination = {
      database_name               = local.db_name
      endpoint_id                 = "${local.name}-destination"
      endpoint_type               = "target"
      engine_name                 = "aurora"
      extra_connection_attributes = ""
      username                    = local.db_username
      password                    = module.rds_aurora["destination"].rds_cluster_master_password
      port                        = 3306
      server_name                 = module.rds_aurora["destination"].rds_cluster_endpoint
      ssl_mode                    = "none"
      tags                        = { EndpointType = "destination" }
    }
  }

  replication_tasks = {
    cdc_ex = {
      replication_task_id       = "${local.name}-cdc"
      migration_type            = "cdc"
      replication_task_settings = file("task_settings.json")
      table_mappings            = file("table_mappings.json")
      source_endpoint_key       = "source"
      target_endpoint_key       = "destination"
      tags                      = { Task = "PostgreSQL-to-MySQL" }
    }
  }

  event_subscriptions = {
    # # Despite what the terraform docs say, this is not valid - you must supply a `source_type`
    # all = {
    #   name                             = "all-events"
    #   enabled                          = true
    #   instance_event_subscription_keys = [local.name]
    #   task_event_subscription_keys     = ["cdc_ex"]
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
      task_event_subscription_keys = ["cdc_ex"]
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
