# IAM roles
### DMS Endpoint
output "dms_access_for_endpoint_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = element(concat(aws_iam_role.dms_access_for_endpoint[*].arn, [""]), 0)
}

output "dms_access_for_endpoint_iam_role_id" {
  description = "Name of the IAM role"
  value       = element(concat(aws_iam_role.dms_access_for_endpoint[*].id, [""]), 0)
}

output "dms_access_for_endpoint_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = element(concat(aws_iam_role.dms_access_for_endpoint[*].unique_id, [""]), 0)
}

### DMS CloudWatch Logs
output "dms_cloudwatch_logs_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = element(concat(aws_iam_role.dms_cloudwatch_logs_role[*].arn, [""]), 0)
}

output "dms_cloudwatch_logs_iam_role_id" {
  description = "Name of the IAM role"
  value       = element(concat(aws_iam_role.dms_cloudwatch_logs_role[*].id, [""]), 0)
}

output "dms_cloudwatch_logs_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = element(concat(aws_iam_role.dms_cloudwatch_logs_role[*].unique_id, [""]), 0)
}

### DMS VPC
output "dms_vpc_iam_role_arn" {
  description = "Amazon Resource Name (ARN) specifying the role"
  value       = element(concat(aws_iam_role.dms_vpc_role[*].arn, [""]), 0)
}

output "dms_vpc_iam_role_id" {
  description = "Name of the IAM role"
  value       = element(concat(aws_iam_role.dms_vpc_role[*].id, [""]), 0)
}

output "dms_vpc_iam_role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = element(concat(aws_iam_role.dms_vpc_role[*].unique_id, [""]), 0)
}

# Subnet group
output "replication_subnet_group_id" {
  description = "The ID of the subnet group"
  value       = element(concat(aws_dms_replication_subnet_group.this[*].id, [""]), 0)
}

# Instance
output "replication_instance_arn" {
  description = "The Amazon Resource Name (ARN) of the replication instance"
  value       = element(concat(aws_dms_replication_instance.this[*].replication_instance_arn, [""]), 0)
}

output "replication_instance_private_ips" {
  description = "A list of the private IP addresses of the replication instance"
  value       = element(concat(aws_dms_replication_instance.this[*].replication_instance_private_ips, [""]), 0)
}

output "replication_instance_public_ips" {
  description = "A list of the public IP addresses of the replication instance"
  value       = element(concat(aws_dms_replication_instance.this[*].replication_instance_public_ips, [""]), 0)
}

output "replication_instance_tags_all" {
  description = "A map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block"
  value       = element(concat(aws_dms_replication_instance.this[*].tags_all, [""]), 0)
}

# Replication Tasks
output "replication_tasks" {
  description = "A map of maps containing the replication tasks created and their full output of attributes and values"
  value       = aws_dms_replication_task.this
}

# Endpoints
output "endpoints" {
  description = "A map of maps containing the endpoints created and their full output of attributes and values"
  value       = aws_dms_endpoint.this
  sensitive   = true
}

# Event Subscriptions
output "event_subscriptions" {
  description = "A map of maps containing the event subscriptions created and their full output of attributes and values"
  value       = aws_dms_event_subscription.this
}

# Certificates
output "certificates" {
  description = "A map of maps containing the certificates created and their full output of attributes and values"
  value       = aws_dms_certificate.this
  sensitive   = true
}
