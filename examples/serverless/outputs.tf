################################################################################
# IAM Roles
################################################################################

# DMS Endpoint
output "dms_access_for_endpoint_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_access_for_endpoint_iam_role_arn
}

output "dms_access_for_endpoint_iam_role_id" {
  description = "Name of the IAM role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_access_for_endpoint_iam_role_id
}

output "dms_access_for_endpoint_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_access_for_endpoint_iam_role_unique_id
}

# DMS CloudWatch Logs
output "dms_cloudwatch_logs_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_cloudwatch_logs_iam_role_arn
}

output "dms_cloudwatch_logs_iam_role_id" {
  description = "Name of the IAM role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_cloudwatch_logs_iam_role_id
}

output "dms_cloudwatch_logs_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_cloudwatch_logs_iam_role_unique_id
}

# DMS VPC
output "dms_vpc_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_vpc_iam_role_arn
}

output "dms_vpc_iam_role_id" {
  description = "Name of the IAM role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_vpc_iam_role_id
}

output "dms_vpc_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = module.dms_aurora_postgresql_aurora_mysql.dms_vpc_iam_role_unique_id
}

################################################################################
# Subnet group
################################################################################

output "replication_subnet_group_id" {
  description = "The ID of the subnet group"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_subnet_group_id
}

################################################################################
# Endpoint
################################################################################

output "endpoints" {
  description = "A map of maps containing the endpoints created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.endpoints
  sensitive   = true
}

################################################################################
# S3 Endpoint
################################################################################

output "s3_endpoints" {
  description = "A map of maps containing the S3 endpoints created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.s3_endpoints
  sensitive   = true
}

################################################################################
# Replication Task
################################################################################

output "serverless_replication_tasks" {
  description = "A map of maps containing the serverless replication tasks created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.serverless_replication_tasks
}
