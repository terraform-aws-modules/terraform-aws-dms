data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name

  subnet_group_id = var.create && var.create_repl_subnet_group ? aws_dms_replication_subnet_group.this[0].id : var.repl_instance_subnet_group_id
}

################################################################################
# IAM Roles
# https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html#CHAP_Security.APIRole
# Issue: https://github.com/hashicorp/terraform-provider-aws/issues/19580
################################################################################

data "aws_iam_policy_document" "dms_assume_role" {
  count = var.create && var.create_iam_roles ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      identifiers = ["dms.${local.dns_suffix}"]
      type        = "Service"
    }

    # https://docs.aws.amazon.com/dms/latest/userguide/cross-service-confused-deputy-prevention.html#cross-service-confused-deputy-prevention-dms-api
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:dms:${local.region}:${local.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "dms_assume_role_redshift" {
  count = var.create && var.create_iam_roles ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.dms_assume_role[0].json]

  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      identifiers = ["redshift.${local.dns_suffix}"]
      type        = "Service"
    }
  }
}

# Time Sleep
resource "time_sleep" "wait_for_dependency_resources" {
  depends_on = [
    aws_iam_role.dms_access_for_endpoint,
    aws_iam_role.dms_cloudwatch_logs_role,
    aws_iam_role.dms_vpc_role
  ]

  create_duration  = "10s"
  destroy_duration = "10s"
}

# DMS Endpoint
resource "aws_iam_role" "dms_access_for_endpoint" {
  count = var.create && var.create_iam_roles ? 1 : 0

  name                  = "dms-access-for-endpoint"
  description           = "DMS IAM role for endpoint access permissions"
  permissions_boundary  = var.iam_role_permissions_boundary
  assume_role_policy    = var.enable_redshift_target_permissions ? data.aws_iam_policy_document.dms_assume_role_redshift[0].json : data.aws_iam_policy_document.dms_assume_role[0].json
  managed_policy_arns   = ["arn:${local.partition}:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"]
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

# DMS CloudWatch Logs
resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  count = var.create && var.create_iam_roles ? 1 : 0

  name                  = "dms-cloudwatch-logs-role"
  description           = "DMS IAM role for CloudWatch logs permissions"
  permissions_boundary  = var.iam_role_permissions_boundary
  assume_role_policy    = data.aws_iam_policy_document.dms_assume_role[0].json
  managed_policy_arns   = ["arn:${local.partition}:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"]
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

# DMS VPC
resource "aws_iam_role" "dms_vpc_role" {
  count = var.create && var.create_iam_roles ? 1 : 0

  name                  = "dms-vpc-role"
  description           = "DMS IAM role for VPC permissions"
  permissions_boundary  = var.iam_role_permissions_boundary
  assume_role_policy    = data.aws_iam_policy_document.dms_assume_role[0].json
  managed_policy_arns   = ["arn:${local.partition}:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"]
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

################################################################################
# Subnet group
################################################################################

resource "aws_dms_replication_subnet_group" "this" {
  count = var.create && var.create_repl_subnet_group ? 1 : 0

  replication_subnet_group_id          = lower(var.repl_subnet_group_name)
  replication_subnet_group_description = var.repl_subnet_group_description
  subnet_ids                           = var.repl_subnet_group_subnet_ids

  tags = merge(var.tags, var.repl_subnet_group_tags)

  depends_on = [time_sleep.wait_for_dependency_resources]
}

################################################################################
# Instance
################################################################################

resource "aws_dms_replication_instance" "this" {
  count = var.create && var.create_repl_instance ? 1 : 0

  allocated_storage            = var.repl_instance_allocated_storage
  allow_major_version_upgrade  = var.repl_instance_allow_major_version_upgrade
  apply_immediately            = var.repl_instance_apply_immediately
  auto_minor_version_upgrade   = var.repl_instance_auto_minor_version_upgrade
  availability_zone            = var.repl_instance_availability_zone
  engine_version               = var.repl_instance_engine_version
  kms_key_arn                  = var.repl_instance_kms_key_arn
  multi_az                     = var.repl_instance_multi_az
  network_type                 = var.repl_instance_network_type
  preferred_maintenance_window = var.repl_instance_preferred_maintenance_window
  publicly_accessible          = var.repl_instance_publicly_accessible
  replication_instance_class   = var.repl_instance_class
  replication_instance_id      = var.repl_instance_id
  replication_subnet_group_id  = local.subnet_group_id
  vpc_security_group_ids       = var.repl_instance_vpc_security_group_ids

  tags = merge(var.tags, var.repl_instance_tags)

  timeouts {
    create = try(var.repl_instance_timeouts.create, null)
    update = try(var.repl_instance_timeouts.update, null)
    delete = try(var.repl_instance_timeouts.delete, null)
  }

  depends_on = [time_sleep.wait_for_dependency_resources]
}

################################################################################
# Endpoint
################################################################################

resource "aws_dms_endpoint" "this" {
  for_each = { for k, v in var.endpoints : k => v if var.create }

  certificate_arn = try(aws_dms_certificate.this[each.value.certificate_key].certificate_arn, null)
  database_name   = lookup(each.value, "database_name", null)

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Elasticsearch.html
  dynamic "elasticsearch_settings" {
    for_each = length(lookup(each.value, "elasticsearch_settings", [])) > 0 ? [each.value.elasticsearch_settings] : []

    content {
      endpoint_uri               = elasticsearch_settings.value.endpoint_uri
      error_retry_duration       = try(elasticsearch_settings.value.error_retry_duration, null)
      full_load_error_percentage = try(elasticsearch_settings.value.full_load_error_percentage, null)
      service_access_role_arn    = lookup(elasticsearch_settings.value, "service_access_role_arn", aws_iam_role.access[0].arn)
      use_new_mapping_type       = try(elasticsearch_settings.value.use_new_mapping_type, null)
    }
  }

  endpoint_id                 = each.value.endpoint_id
  endpoint_type               = each.value.endpoint_type
  engine_name                 = each.value.engine_name
  extra_connection_attributes = try(each.value.extra_connection_attributes, null)

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kafka.html
  dynamic "kafka_settings" {
    for_each = length(lookup(each.value, "kafka_settings", [])) > 0 ? [each.value.kafka_settings] : []

    content {
      broker                         = kafka_settings.value.broker
      include_control_details        = try(kafka_settings.value.include_control_details, null)
      include_null_and_empty         = try(kafka_settings.value.include_null_and_empty, null)
      include_partition_value        = try(kafka_settings.value.include_partition_value, null)
      include_table_alter_operations = try(kafka_settings.value.include_table_alter_operations, null)
      include_transaction_details    = try(kafka_settings.value.include_transaction_details, null)
      message_format                 = try(kafka_settings.value.message_format, null)
      message_max_bytes              = try(kafka_settings.value.message_max_bytes, null)
      no_hex_prefix                  = try(kafka_settings.value.no_hex_prefix, null)
      partition_include_schema_table = try(kafka_settings.value.partition_include_schema_table, null)
      sasl_password                  = lookup(kafka_settings.value, "sasl_password", null)
      sasl_username                  = lookup(kafka_settings.value, "sasl_username", null)
      security_protocol              = try(kafka_settings.value.security_protocol, null)
      ssl_ca_certificate_arn         = lookup(kafka_settings.value, "ssl_ca_certificate_arn", null)
      ssl_client_certificate_arn     = lookup(kafka_settings.value, "ssl_client_certificate_arn", null)
      ssl_client_key_arn             = lookup(kafka_settings.value, "ssl_client_key_arn", null)
      ssl_client_key_password        = lookup(kafka_settings.value, "ssl_client_key_password", null)
      topic                          = try(kafka_settings.value.topic, null)
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kinesis.html
  dynamic "kinesis_settings" {
    for_each = length(lookup(each.value, "kinesis_settings", [])) > 0 ? [each.value.kinesis_settings] : []

    content {
      include_control_details        = try(kinesis_settings.value.include_control_details, null)
      include_null_and_empty         = try(kinesis_settings.value.include_null_and_empty, null)
      include_partition_value        = try(kinesis_settings.value.include_partition_value, null)
      include_table_alter_operations = try(kinesis_settings.value.include_table_alter_operations, null)
      include_transaction_details    = try(kinesis_settings.value.include_transaction_details, null)
      message_format                 = try(kinesis_settings.value.message_format, null)
      partition_include_schema_table = try(kinesis_settings.value.partition_include_schema_table, null)
      service_access_role_arn        = lookup(kinesis_settings.value, "service_access_role_arn", local.access_iam_role)
      stream_arn                     = lookup(kinesis_settings.value, "stream_arn", null)
    }
  }

  kms_key_arn = lookup(each.value, "kms_key_arn", null)

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.MongoDB.html
  dynamic "mongodb_settings" {
    for_each = length(lookup(each.value, "mongodb_settings", [])) > 0 ? [each.value.mongodb_settings] : []

    content {
      auth_mechanism      = try(mongodb_settings.value.auth_mechanism, null)
      auth_source         = try(mongodb_settings.value.auth_source, null)
      auth_type           = try(mongodb_settings.value.auth_type, null)
      docs_to_investigate = try(mongodb_settings.value.docs_to_investigate, null)
      extract_doc_id      = try(mongodb_settings.value.extract_doc_id, null)
      nesting_level       = try(mongodb_settings.value.nesting_level, null)
    }
  }

  password                = lookup(each.value, "password", null)
  pause_replication_tasks = try(each.value.pause_replication_tasks, null)
  port                    = try(each.value.port, null)

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.PostgreSQL.html
  dynamic "postgres_settings" {
    for_each = length(lookup(each.value, "postgres_settings", [])) > 0 ? [each.value.postgres_settings] : []
    content {
      after_connect_script         = try(postgres_settings.value.after_connect_script, null)
      babelfish_database_name      = try(postgres_settings.value.babelfish_database_name, null)
      capture_ddls                 = try(postgres_settings.value.capture_ddls, null)
      database_mode                = try(postgres_settings.value.database_mode, null)
      ddl_artifacts_schema         = try(postgres_settings.value.ddl_artifacts_schema, null)
      execute_timeout              = try(postgres_settings.value.execute_timeout, null)
      fail_tasks_on_lob_truncation = try(postgres_settings.value.fail_tasks_on_lob_truncation, null)
      heartbeat_enable             = try(postgres_settings.value.heartbeat_enable, null)
      heartbeat_frequency          = try(postgres_settings.value.heartbeat_frequency, null)
      heartbeat_schema             = try(postgres_settings.value.heartbeat_schema, null)
      map_boolean_as_boolean       = try(postgres_settings.value.map_boolean_as_boolean, null)
      map_jsonb_as_clob            = try(postgres_settings.value.map_jsonb_as_clob, null)
      map_long_varchar_as          = try(postgres_settings.value.map_long_varchar_as, null)
      max_file_size                = try(postgres_settings.value.max_file_size, null)
      plugin_name                  = try(postgres_settings.value.plugin_name, null)
      slot_name                    = try(postgres_settings.value.slot_name, null)
    }
  }

  dynamic "redis_settings" {
    for_each = length(lookup(each.value, "redis_settings", [])) > 0 ? [each.value.redis_settings] : []

    content {
      auth_password          = try(redis_settings.value.auth_password, null)
      auth_type              = redis_settings.value.auth_type
      auth_user_name         = try(redis_settings.value.auth_user_name, null)
      port                   = try(redis_settings.value.port, 6379)
      server_name            = redis_settings.value.server_name
      ssl_ca_certificate_arn = lookup(redis_settings.value, "ssl_ca_certificate_arn", null)
      ssl_security_protocol  = try(redis_settings.value.ssl_security_protocol, null)
    }
  }

  dynamic "redshift_settings" {
    for_each = length(lookup(each.value, "redshift_settings", [])) > 0 ? [each.value.redshift_settings] : []

    content {
      bucket_folder                     = try(redshift_settings.value.bucket_folder, null)
      bucket_name                       = lookup(redshift_settings.value, "bucket_name", null)
      encryption_mode                   = try(redshift_settings.value.encryption_mode, null)
      server_side_encryption_kms_key_id = lookup(redshift_settings.value, "server_side_encryption_kms_key_id", null)
      service_access_role_arn           = lookup(redshift_settings.value, "service_access_role_arn", "arn:${local.partition}:iam::${local.account_id}:role/dms-access-for-endpoint")
    }
  }

  secrets_manager_access_role_arn = lookup(each.value, "secrets_manager_arn", null) != null ? lookup(each.value, "secrets_manager_access_role_arn", local.access_iam_role) : null
  secrets_manager_arn             = lookup(each.value, "secrets_manager_arn", null)
  server_name                     = lookup(each.value, "server_name", null)
  service_access_role             = lookup(each.value, "service_access_role", local.access_iam_role)
  ssl_mode                        = try(each.value.ssl_mode, null)
  username                        = try(each.value.username, null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# S3 Endpoint
################################################################################

resource "aws_dms_s3_endpoint" "this" {
  for_each = { for k, v in var.s3_endpoints : k => v if var.create }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.S3.html
  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.S3.html
  certificate_arn = try(aws_dms_certificate.this[each.value.certificate_key].certificate_arn, null)
  endpoint_id     = each.value.endpoint_id
  endpoint_type   = each.value.endpoint_type
  kms_key_arn     = lookup(each.value, "kms_key_arn", null)
  ssl_mode        = try(each.value.ssl_mode, null)

  add_column_name                             = try(each.value.add_column_name, null)
  add_trailing_padding_character              = try(each.value.add_trailing_padding_character, null)
  bucket_folder                               = try(each.value.bucket_folder, null)
  bucket_name                                 = each.value.bucket_name
  canned_acl_for_objects                      = try(each.value.canned_acl_for_objects, null)
  cdc_inserts_and_updates                     = try(each.value.cdc_inserts_and_updates, null)
  cdc_inserts_only                            = try(each.value.cdc_inserts_only, null)
  cdc_max_batch_interval                      = try(each.value.cdc_max_batch_interval, null)
  cdc_min_file_size                           = try(each.value.cdc_min_file_size, null)
  cdc_path                                    = try(each.value.cdc_path, null)
  compression_type                            = try(each.value.compression_type, null)
  csv_delimiter                               = try(each.value.csv_delimiter, null)
  csv_no_sup_value                            = try(each.value.csv_no_sup_value, null)
  csv_null_value                              = try(each.value.csv_null_value, null)
  csv_row_delimiter                           = try(each.value.csv_row_delimiter, null)
  data_format                                 = try(each.value.data_format, null)
  data_page_size                              = try(each.value.data_page_size, null)
  date_partition_delimiter                    = try(each.value.date_partition_delimiter, null)
  date_partition_enabled                      = try(each.value.date_partition_enabled, null)
  date_partition_sequence                     = try(each.value.date_partition_sequence, null)
  date_partition_timezone                     = try(each.value.date_partition_timezone, null)
  detach_target_on_lob_lookup_failure_parquet = try(each.value.detach_target_on_lob_lookup_failure_parquet, null)
  dict_page_size_limit                        = try(each.value.dict_page_size_limit, null)
  enable_statistics                           = try(each.value.enable_statistics, null)
  encoding_type                               = try(each.value.encoding_type, null)
  encryption_mode                             = try(each.value.encryption_mode, null)
  expected_bucket_owner                       = try(each.value.expected_bucket_owner, null)
  external_table_definition                   = try(each.value.external_table_definition, null)
  glue_catalog_generation                     = try(each.value.glue_catalog_generation, null)
  ignore_header_rows                          = try(each.value.ignore_header_rows, null)
  include_op_for_full_load                    = try(each.value.include_op_for_full_load, null)
  max_file_size                               = try(each.value.max_file_size, null)
  parquet_timestamp_in_millisecond            = try(each.value.parquet_timestamp_in_millisecond, null)
  parquet_version                             = try(each.value.parquet_version, null)
  preserve_transactions                       = try(each.value.preserve_transactions, null)
  rfc_4180                                    = try(each.value.rfc_4180, null)
  row_group_length                            = try(each.value.row_group_length, null)
  server_side_encryption_kms_key_id           = lookup(each.value, "server_side_encryption_kms_key_id", null)
  service_access_role_arn                     = lookup(each.value, "service_access_role_arn", local.access_iam_role)
  timestamp_column_name                       = try(each.value.timestamp_column_name, null)
  use_csv_no_sup_value                        = try(each.value.use_csv_no_sup_value, null)
  use_task_start_time_for_full_load_timestamp = try(each.value.use_task_start_time_for_full_load_timestamp, null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# Replication Task - Instance
################################################################################

resource "aws_dms_replication_task" "this" {
  for_each = { for k, v in var.replication_tasks : k => v if var.create && ! contains(keys(v), "serverless_config") }

  cdc_start_position        = try(each.value.cdc_start_position, null)
  cdc_start_time            = try(each.value.cdc_start_time, null)
  migration_type            = each.value.migration_type
  replication_instance_arn  = aws_dms_replication_instance.this[0].replication_instance_arn
  replication_task_id       = each.value.replication_task_id
  replication_task_settings = try(each.value.replication_task_settings, null)
  source_endpoint_arn       = try(aws_dms_endpoint.this[each.value.source_endpoint_key].endpoint_arn, aws_dms_s3_endpoint.this[each.value.source_endpoint_key].endpoint_arn)
  start_replication_task    = try(each.value.start_replication_task, null)
  table_mappings            = try(each.value.table_mappings, null)
  target_endpoint_arn       = try(aws_dms_endpoint.this[each.value.target_endpoint_key].endpoint_arn, aws_dms_s3_endpoint.this[each.value.target_endpoint_key].endpoint_arn)

  tags = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# Replication Task - Serverless
################################################################################
resource "aws_dms_replication_config" "this" {
  for_each = { for k, v in var.replication_tasks : k => v if var.create && contains(keys(v), "serverless_config") }

  replication_config_identifier = each.value.replication_task_id
  resource_identifier           = each.value.replication_task_id

  replication_type    = each.value.migration_type
  source_endpoint_arn = try(aws_dms_endpoint.this[each.value.source_endpoint_key].endpoint_arn, aws_dms_s3_endpoint.this[each.value.source_endpoint_key].endpoint_arn)
  target_endpoint_arn = try(aws_dms_endpoint.this[each.value.target_endpoint_key].endpoint_arn, aws_dms_s3_endpoint.this[each.value.target_endpoint_key].endpoint_arn)
  table_mappings      = try(each.value.table_mappings, null)

  replication_settings  = try(each.value.replication_task_settings, null)
  supplemental_settings = try(each.value.supplemental_task_settings, null)

  start_replication = try(each.value.start_replication_task, null)

  compute_config {
    availability_zone            = try(each.value.serverless_config.availability_zone, null)
    dns_name_servers             = try(each.value.serverless_config.dns_name_servers, null)
    kms_key_id                   = try(each.value.serverless_config.kms_key_id, null)
    max_capacity_units           = each.value.serverless_config.max_capacity_units
    min_capacity_units           = try(each.value.serverless_config.min_capacity_units, null)
    multi_az                     = try(each.value.serverless_config.multi_az, null)
    preferred_maintenance_window = try(each.value.serverless_config.preferred_maintenance_window, null)
    replication_subnet_group_id  = local.subnet_group_id
    vpc_security_group_ids       = try(each.value.serverless_config.vpc_security_group_ids, null)
  }

  tags = merge(var.tags, try(each.value.tags, {}))
}


################################################################################
# Event Subscription
################################################################################

resource "aws_dms_event_subscription" "this" {
  for_each = { for k, v in var.event_subscriptions : k => v if var.create }

  enabled          = try(each.value.enabled, null)
  event_categories = try(each.value.event_categories, null)
  name             = each.value.name
  sns_topic_arn    = each.value.sns_topic_arn

  source_ids = compact(concat(
    [
      for instance in aws_dms_replication_instance.this[*] :
      instance.replication_instance_id if lookup(each.value, "instance_event_subscription_keys", null) == var.repl_instance_id
    ],
    [
      for task in aws_dms_replication_task.this[*] :
      task.replication_task_id if contains(lookup(each.value, "task_event_subscription_keys", []), each.key)
    ]
  ))

  source_type = try(each.value.source_type, null)

  tags = merge(var.tags, try(each.value.tags, {}))

  timeouts {
    create = try(var.event_subscription_timeouts.create, null)
    update = try(var.event_subscription_timeouts.update, null)
    delete = try(var.event_subscription_timeouts.delete, null)
  }
}

################################################################################
# Certificate
################################################################################

resource "aws_dms_certificate" "this" {
  for_each = { for k, v in var.certificates : k => v if var.create }

  certificate_id     = each.value.certificate_id
  certificate_pem    = lookup(each.value, "certificate_pem", null)
  certificate_wallet = lookup(each.value, "certificate_wallet", null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# Access IAM Role
################################################################################

locals {
  access_iam_role_name   = try(coalesce(var.access_iam_role_name, var.repl_instance_id), "")
  create_access_iam_role = var.create && var.create_access_iam_role
  create_access_policy   = local.create_access_iam_role && var.create_access_policy

  access_iam_role = local.create_access_iam_role ? aws_iam_role.access[0].arn : null
}

data "aws_iam_policy_document" "access_assume" {
  count = local.create_access_iam_role ? 1 : 0

  statement {
    sid = "DMSAssumeRole"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      identifiers = [
        "dms.${local.dns_suffix}",
        "dms.${local.region}.${local.dns_suffix}",
      ]
      type = "Service"
    }

    # https://docs.aws.amazon.com/dms/latest/userguide/cross-service-confused-deputy-prevention.html#cross-service-confused-deputy-prevention-dms-api
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:dms:${local.region}:${local.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "access" {
  count = local.create_access_iam_role ? 1 : 0

  name        = var.access_iam_role_use_name_prefix ? null : local.access_iam_role_name
  name_prefix = var.access_iam_role_use_name_prefix ? "${local.access_iam_role_name}-" : null
  path        = var.access_iam_role_path
  description = coalesce(var.access_iam_role_description, "Service access role")

  assume_role_policy    = data.aws_iam_policy_document.access_assume[0].json
  permissions_boundary  = var.access_iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.access_iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "access_additional" {
  for_each = { for k, v in var.access_iam_role_policies : k => v if local.create_access_iam_role }

  role       = aws_iam_role.access[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "access" {
  count = local.create_access_policy ? 1 : 0

  statement {
    sid = "KMS"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = coalescelist(
      var.access_kms_key_arns,
      ["arn:${local.partition}:kms:${local.region}:${local.account_id}:key/*"]
    )
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/security_iam_secretsmanager.html
  dynamic "statement" {
    for_each = length(var.access_secret_arns) > 0 ? [1] : []

    content {
      sid       = "SecretsManager"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.access_secret_arns
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.S3.html#CHAP_Source.S3.Prerequisites
  dynamic "statement" {
    for_each = length(var.access_source_s3_bucket_arns) > 0 ? [1] : []

    content {
      sid = "S3Source"
      actions = [
        "s3:ListBucket",
        "s3:GetObject",
        "S3:GetObjectVersion",
      ]
      resources = var.access_source_s3_bucket_arns
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.S3.html#CHAP_Target.S3.Prerequisites
  dynamic "statement" {
    for_each = length(var.access_target_s3_bucket_arns) > 0 ? [1] : []

    content {
      sid = "S3Target"
      actions = [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutObjectTagging",
      ]
      resources = var.access_target_s3_bucket_arns
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Elasticsearch.html#CHAP_Target.Elasticsearch.Prerequisites
  dynamic "statement" {
    for_each = length(var.access_target_elasticsearch_arns) > 0 ? [1] : []

    content {
      sid = "ElasticSearchTarget"
      actions = [
        "es:ESHttpDelete",
        "es:ESHttpGet",
        "es:ESHttpHead",
        "es:ESHttpPost",
        "es:ESHttpPut",
      ]
      resources = var.access_target_elasticsearch_arns
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kinesis.html#CHAP_Target.Kinesis.Prerequisites
  dynamic "statement" {
    for_each = length(var.access_target_kinesis_arns) > 0 ? [1] : []

    content {
      sid = "KinesisTarget"
      actions = [
        "kinesis:DescribeStream",
        "kinesis:PutRecord",
        "kinesis:PutRecords",
      ]
      resources = var.access_target_kinesis_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.access_target_dynamodb_table_arns) > 0 ? [1] : []

    content {
      sid       = "DynamoDBList"
      actions   = ["dynamodb:ListTables"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.access_target_dynamodb_table_arns) > 0 ? [1] : []

    content {
      sid = "DynamoDBTarget"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ]
      resources = var.access_target_dynamodb_table_arns
    }
  }

  dynamic "statement" {
    for_each = var.access_iam_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}

resource "aws_iam_policy" "access" {
  count = local.create_access_policy ? 1 : 0

  name        = var.access_iam_role_use_name_prefix ? null : local.access_iam_role_name
  name_prefix = var.access_iam_role_use_name_prefix ? "${local.access_iam_role_name}-" : null
  description = coalesce(var.access_iam_role_description, "Service access role IAM policy")
  policy      = data.aws_iam_policy_document.access[0].json

  tags = merge(var.tags, var.access_iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "access" {
  count = local.create_access_policy ? 1 : 0

  role       = aws_iam_role.access[0].name
  policy_arn = aws_iam_policy.access[0].arn
}
