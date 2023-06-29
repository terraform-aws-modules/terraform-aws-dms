################################################################################
# IAM Roles
################################################################################

# DMS Endpoint
output "dms_access_for_endpoint_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = try(aws_iam_role.dms_access_for_endpoint[0].arn, null)
}

output "dms_access_for_endpoint_iam_role_id" {
  description = "Name of the IAM role"
  value       = try(aws_iam_role.dms_access_for_endpoint[0].id, null)
}

output "dms_access_for_endpoint_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = try(aws_iam_role.dms_access_for_endpoint[0].unique_id, null)
}

# DMS CloudWatch Logs
output "dms_cloudwatch_logs_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = try(aws_iam_role.dms_cloudwatch_logs_role[0].arn, null)
}

output "dms_cloudwatch_logs_iam_role_id" {
  description = "Name of the IAM role"
  value       = try(aws_iam_role.dms_cloudwatch_logs_role[0].id, null)
}

output "dms_cloudwatch_logs_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = try(aws_iam_role.dms_cloudwatch_logs_role[0].unique_id, null)
}

# DMS VPC
output "dms_vpc_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = try(aws_iam_role.dms_vpc_role[0].arn, null)
}

output "dms_vpc_iam_role_id" {
  description = "Name of the IAM role"
  value       = try(aws_iam_role.dms_vpc_role[0].id, null)
}

output "dms_vpc_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = try(aws_iam_role.dms_vpc_role[0].unique_id, null)
}

################################################################################
# Subnet group
################################################################################

output "replication_subnet_group_id" {
  description = "The ID of the subnet group"
  value       = try(aws_dms_replication_subnet_group.this[0].id, null)
}

################################################################################
# Instance
################################################################################

output "replication_instance_arn" {
  description = "The Amazon Resource Name (ARN) of the replication instance"
  value       = try(aws_dms_replication_instance.this[0].replication_instance_arn, null)
}

output "replication_instance_private_ips" {
  description = "A list of the private IP addresses of the replication instance"
  value       = try(aws_dms_replication_instance.this[0].replication_instance_private_ips, null)
}

output "replication_instance_public_ips" {
  description = "A list of the public IP addresses of the replication instance"
  value       = try(aws_dms_replication_instance.this[0].replication_instance_public_ips, null)
}

output "replication_instance_tags_all" {
  description = "A map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block"
  value       = try(aws_dms_replication_instance.this[0].tags_all, null)
}

################################################################################
# Endpoint
################################################################################

output "endpoints" {
  description = "A map of maps containing the endpoints created and their full output of attributes and values"
  value       = aws_dms_endpoint.this
  sensitive   = true
}

################################################################################
# S3 Endpoint
################################################################################

output "s3_endpoints" {
  description = "A map of maps containing the S3 endpoints created and their full output of attributes and values"
  value       = aws_dms_s3_endpoint.this
  sensitive   = true
}

################################################################################
# Replication Task
################################################################################

output "replication_tasks" {
  description = "A map of maps containing the replication tasks created and their full output of attributes and values"
  value       = aws_dms_replication_task.this
}

################################################################################
# Event Subscription
################################################################################

output "event_subscriptions" {
  description = "A map of maps containing the event subscriptions created and their full output of attributes and values"
  value       = aws_dms_event_subscription.this
}

################################################################################
# Certificate
################################################################################

output "certificates" {
  description = "A map of maps containing the certificates created and their full output of attributes and values"
  value       = aws_dms_certificate.this
  sensitive   = true
}
