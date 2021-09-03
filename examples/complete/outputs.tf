# IAM roles
### DMS Endpoint
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

### DMS CloudWatch Logs
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

### DMS VPC
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

# Subnet group
output "replication_subnet_group_id" {
  description = "The ID of the subnet group"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_subnet_group_id
}

# Instance
output "replication_instance_arn" {
  description = "The Amazon Resource Name (ARN) of the replication instance"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_instance_arn
}

output "replication_instance_private_ips" {
  description = "A list of the private IP addresses of the replication instance"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_instance_private_ips
}

output "replication_instance_public_ips" {
  description = "A list of the public IP addresses of the replication instance"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_instance_public_ips
}

output "replication_instance_tags_all" {
  description = "A map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_instance_tags_all
}

# Replication Tasks
output "replication_tasks" {
  description = "A map of maps containing the replication tasks created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.replication_tasks
}

# Endpoints
output "endpoints" {
  description = "A map of maps containing the endpoints created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.endpoints
  sensitive   = true
}

# Event Subscriptions
output "event_subscriptions" {
  description = "A map of maps containing the event subscriptions created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.event_subscriptions
}

# Certificates
output "certificates" {
  description = "A map of maps containing the certificates created and their full output of attributes and values"
  value       = module.dms_aurora_postgresql_aurora_mysql.certificates
  sensitive   = true
}
