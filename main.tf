locals {
  subnet_group_id = var.create && var.create_repl_subnet_group ? aws_dms_replication_subnet_group.this[0].id : var.repl_instance_subnet_group_id

  partition  = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix
}

data "aws_partition" "current" {}

################################################################################
# IAM Roles
# https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html#CHAP_Security.APIRole
# Issue: https://github.com/hashicorp/terraform-provider-aws/issues/19580
################################################################################

data "aws_iam_policy_document" "dms_assume_role" {
  count = var.create && var.create_iam_roles ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.${local.dns_suffix}"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "dms_assume_role_redshift" {
  count = var.create && var.create_iam_roles ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.dms_assume_role[0].json]

  statement {
    actions = ["sts:AssumeRole"]

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
  count = var.create ? 1 : 0

  allocated_storage            = var.repl_instance_allocated_storage
  auto_minor_version_upgrade   = var.repl_instance_auto_minor_version_upgrade
  allow_major_version_upgrade  = var.repl_instance_allow_major_version_upgrade
  apply_immediately            = var.repl_instance_apply_immediately
  availability_zone            = var.repl_instance_availability_zone
  engine_version               = var.repl_instance_engine_version
  kms_key_arn                  = var.repl_instance_kms_key_arn
  multi_az                     = var.repl_instance_multi_az
  preferred_maintenance_window = var.repl_instance_preferred_maintenance_window
  publicly_accessible          = var.repl_instance_publicly_accessible
  replication_instance_class   = var.repl_instance_class
  replication_instance_id      = var.repl_instance_id
  replication_subnet_group_id  = local.subnet_group_id
  vpc_security_group_ids       = var.repl_instance_vpc_security_group_ids

  tags = merge(var.tags, var.repl_instance_tags)

  timeouts {
    create = lookup(var.repl_instance_timeouts, "create", null)
    update = lookup(var.repl_instance_timeouts, "update", null)
    delete = lookup(var.repl_instance_timeouts, "delete", null)
  }

  depends_on = [time_sleep.wait_for_dependency_resources]
}

################################################################################
# Endpoint
################################################################################

resource "aws_dms_endpoint" "this" {
  for_each = { for k, v in var.endpoints : k => v if var.create }

  certificate_arn                 = try(aws_dms_certificate.this[each.value.certificate_key].certificate_arn, null)
  database_name                   = lookup(each.value, "database_name", null)
  endpoint_id                     = each.value.endpoint_id
  endpoint_type                   = each.value.endpoint_type
  engine_name                     = each.value.engine_name
  extra_connection_attributes     = lookup(each.value, "extra_connection_attributes", null)
  kms_key_arn                     = lookup(each.value, "kms_key_arn", null)
  password                        = lookup(each.value, "password", null)
  port                            = lookup(each.value, "port", null)
  server_name                     = lookup(each.value, "server_name", null)
  service_access_role             = lookup(each.value, "service_access_role", null)
  ssl_mode                        = lookup(each.value, "ssl_mode", null)
  username                        = lookup(each.value, "username", null)
  secrets_manager_access_role_arn = lookup(each.value, "secrets_manager_access_role_arn", null)
  secrets_manager_arn             = lookup(each.value, "secrets_manager_arn", null)

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Elasticsearch.html
  dynamic "elasticsearch_settings" {
    for_each = length(lookup(each.value, "elasticsearch_settings", {})) == 0 ? [] : [each.value.elasticsearch_settings]

    content {
      endpoint_uri               = elasticsearch_settings.value.endpoint_uri
      error_retry_duration       = lookup(elasticsearch_settings.value, "error_retry_duration", null)
      full_load_error_percentage = lookup(elasticsearch_settings.value, "full_load_error_percentage", null)
      service_access_role_arn    = lookup(elasticsearch_settings.value, "service_access_role_arn", null)
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kafka.html
  dynamic "kafka_settings" {
    for_each = length(lookup(each.value, "kafka_settings", {})) == 0 ? [] : [each.value.kafka_settings]

    content {
      broker                         = kafka_settings.value.broker
      include_control_details        = lookup(kafka_settings.value, "include_control_details", null)
      include_null_and_empty         = lookup(kafka_settings.value, "include_null_and_empty", null)
      include_partition_value        = lookup(kafka_settings.value, "include_partition_value", null)
      include_table_alter_operations = lookup(kafka_settings.value, "include_table_alter_operations", null)
      include_transaction_details    = lookup(kafka_settings.value, "include_transaction_details", null)
      message_format                 = lookup(kafka_settings.value, "message_format", null)
      message_max_bytes              = lookup(kafka_settings.value, "message_max_bytes", null)
      no_hex_prefix                  = lookup(kafka_settings.value, "no_hex_prefix", null)
      partition_include_schema_table = lookup(kafka_settings.value, "partition_include_schema_table", null)
      sasl_password                  = lookup(kafka_settings.value, "sasl_password", null)
      sasl_username                  = lookup(kafka_settings.value, "sasl_username", null)
      security_protocol              = lookup(kafka_settings.value, "security_protocol", null)
      ssl_ca_certificate_arn         = lookup(kafka_settings.value, "ssl_ca_certificate_arn", null)
      ssl_client_certificate_arn     = lookup(kafka_settings.value, "ssl_client_certificate_arn", null)
      ssl_client_key_arn             = lookup(kafka_settings.value, "ssl_client_key_arn", null)
      ssl_client_key_password        = lookup(kafka_settings.value, "ssl_client_key_password", null)
      topic                          = lookup(kafka_settings.value, "topic", null)
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kinesis.html
  dynamic "kinesis_settings" {
    for_each = length(lookup(each.value, "kinesis_settings", {})) == 0 ? [] : [each.value.kinesis_settings]

    content {
      include_control_details        = lookup(kinesis_settings.value, "include_control_details", null)
      include_null_and_empty         = lookup(kinesis_settings.value, "include_null_and_empty", null)
      include_partition_value        = lookup(kinesis_settings.value, "include_partition_value", null)
      include_table_alter_operations = lookup(kinesis_settings.value, "include_table_alter_operations", null)
      include_transaction_details    = lookup(kinesis_settings.value, "include_transaction_details", null)
      message_format                 = lookup(kinesis_settings.value, "message_format", null)
      partition_include_schema_table = lookup(kinesis_settings.value, "partition_include_schema_table", null)
      service_access_role_arn        = lookup(kinesis_settings.value, "service_access_role_arn", null)
      stream_arn                     = lookup(kinesis_settings.value, "stream_arn", null)
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.MongoDB.html
  dynamic "mongodb_settings" {
    for_each = length(lookup(each.value, "mongodb_settings", {})) == 0 ? [] : [each.value.mongodb_settings]

    content {
      auth_mechanism      = lookup(mongodb_settings.value, "auth_mechanism", null)
      auth_source         = lookup(mongodb_settings.value, "auth_source", null)
      auth_type           = lookup(mongodb_settings.value, "auth_type", null)
      docs_to_investigate = lookup(mongodb_settings.value, "docs_to_investigate", null)
      extract_doc_id      = lookup(mongodb_settings.value, "extract_doc_id", null)
      nesting_level       = lookup(mongodb_settings.value, "nesting_level", null)
    }
  }

  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.S3.html
  # https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.S3.html
  dynamic "s3_settings" {
    for_each = length(lookup(each.value, "s3_settings", {})) == 0 ? [] : [each.value.s3_settings]

    content {
      add_column_name                   = lookup(s3_settings.value, "add_column_name", null)
      bucket_folder                     = lookup(s3_settings.value, "bucket_folder", null)
      bucket_name                       = lookup(s3_settings.value, "bucket_name", null)
      canned_acl_for_objects            = lookup(s3_settings.value, "canned_acl_for_objects", null)
      cdc_inserts_and_updates           = lookup(s3_settings.value, "cdc_inserts_and_updates", null)
      cdc_inserts_only                  = lookup(s3_settings.value, "cdc_inserts_only", null)
      cdc_max_batch_interval            = lookup(s3_settings.value, "cdc_max_batch_interval", null)
      cdc_min_file_size                 = lookup(s3_settings.value, "cdc_min_file_size", null)
      cdc_path                          = lookup(s3_settings.value, "cdc_path", null)
      compression_type                  = lookup(s3_settings.value, "compression_type", null)
      csv_delimiter                     = lookup(s3_settings.value, "csv_delimiter", null)
      csv_no_sup_value                  = lookup(s3_settings.value, "csv_no_sup_value", null)
      csv_null_value                    = lookup(s3_settings.value, "csv_null_value", null)
      csv_row_delimiter                 = lookup(s3_settings.value, "csv_row_delimiter", null)
      data_format                       = lookup(s3_settings.value, "data_format", null)
      data_page_size                    = lookup(s3_settings.value, "data_page_size", null)
      date_partition_delimiter          = lookup(s3_settings.value, "date_partition_delimiter", null)
      date_partition_enabled            = lookup(s3_settings.value, "date_partition_enabled", null)
      date_partition_sequence           = lookup(s3_settings.value, "date_partition_sequence", null)
      dict_page_size_limit              = lookup(s3_settings.value, "dict_page_size_limit", null)
      enable_statistics                 = lookup(s3_settings.value, "enable_statistics", null)
      encoding_type                     = lookup(s3_settings.value, "encoding_type", null)
      encryption_mode                   = lookup(s3_settings.value, "encryption_mode", null)
      external_table_definition         = lookup(s3_settings.value, "external_table_definition", null)
      ignore_header_rows                = lookup(s3_settings.value, "ignore_header_rows", null)
      include_op_for_full_load          = lookup(s3_settings.value, "include_op_for_full_load", null)
      max_file_size                     = lookup(s3_settings.value, "max_file_size", null)
      parquet_timestamp_in_millisecond  = lookup(s3_settings.value, "parquet_timestamp_in_millisecond", null)
      parquet_version                   = lookup(s3_settings.value, "parquet_version", null)
      preserve_transactions             = lookup(s3_settings.value, "preserve_transactions", null)
      rfc_4180                          = lookup(s3_settings.value, "rfc_4180", null)
      row_group_length                  = lookup(s3_settings.value, "row_group_length", null)
      server_side_encryption_kms_key_id = lookup(s3_settings.value, "server_side_encryption_kms_key_id", null)
      service_access_role_arn           = lookup(s3_settings.value, "service_access_role_arn", null)
      timestamp_column_name             = lookup(s3_settings.value, "timestamp_column_name", null)
      use_csv_no_sup_value              = lookup(s3_settings.value, "use_csv_no_sup_value", null)
    }
  }

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

################################################################################
# Replication Task
################################################################################

resource "aws_dms_replication_task" "this" {
  for_each = { for k, v in var.replication_tasks : k => v if var.create }

  cdc_start_position        = lookup(each.value, "cdc_start_position", null)
  cdc_start_time            = lookup(each.value, "cdc_start_time", null)
  migration_type            = each.value.migration_type
  replication_instance_arn  = aws_dms_replication_instance.this[0].replication_instance_arn
  replication_task_id       = each.value.replication_task_id
  replication_task_settings = lookup(each.value, "replication_task_settings", null)
  table_mappings            = lookup(each.value, "table_mappings", null)
  source_endpoint_arn       = aws_dms_endpoint.this[each.value.source_endpoint_key].endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.this[each.value.target_endpoint_key].endpoint_arn
  start_replication_task    = lookup(each.value, "start_replication_task", null)

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

################################################################################
# Event Subscription
################################################################################

resource "aws_dms_event_subscription" "this" {
  for_each = { for k, v in var.event_subscriptions : k => v if var.create }

  name             = each.value.name
  enabled          = lookup(each.value, "enabled", null)
  event_categories = lookup(each.value, "event_categories", null)
  source_type      = lookup(each.value, "source_type", null)
  source_ids = compact(concat([
    for instance in aws_dms_replication_instance.this[*] :
    instance.replication_instance_id if lookup(each.value, "instance_event_subscription_keys", null) == var.repl_instance_id
    ], [
    for task in aws_dms_replication_task.this[*] :
    task.replication_task_id if contains(lookup(each.value, "task_event_subscription_keys", []), each.key)
  ]))

  sns_topic_arn = each.value.sns_topic_arn

  tags = merge(var.tags, lookup(each.value, "tags", {}))

  timeouts {
    create = lookup(var.event_subscription_timeouts, "create", null)
    update = lookup(var.event_subscription_timeouts, "update", null)
    delete = lookup(var.event_subscription_timeouts, "delete", null)
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

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}
