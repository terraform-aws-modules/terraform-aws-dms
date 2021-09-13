variable "create" {
  description = "Determines whether resources will be created"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}
}

# IAM roles
variable "create_iam_roles" {
  description = "Determines whether the required [DMS IAM resources](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html#CHAP_Security.APIRole) will be created"
  type        = bool
  default     = true
}

variable "iam_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the role"
  type        = string
  default     = null
}

variable "iam_role_tags" {
  description = "A map of additional tags to apply to the DMS IAM roles"
  type        = map(string)
  default     = {}
}

# Subnet group
variable "create_repl_subnet_group" {
  description = "Determines whether the replication subnet group will be created"
  type        = bool
  default     = true
}

variable "repl_subnet_group_description" {
  description = "The description for the subnet group"
  type        = string
  default     = null
}

variable "repl_subnet_group_name" {
  description = "The name for the replication subnet group. Stored as a lowercase string, must contain no more than 255 alphanumeric characters, periods, spaces, underscores, or hyphens"
  type        = string
  default     = null
}

variable "repl_subnet_group_subnet_ids" {
  description = "A list of the EC2 subnet IDs for the subnet group"
  type        = list(string)
  default     = []
}

variable "repl_subnet_group_tags" {
  description = "A map of additional tags to apply to the replication subnet group"
  type        = map(string)
  default     = {}
}

# Instance
variable "repl_instance_allocated_storage" {
  description = "The amount of storage (in gigabytes) to be initially allocated for the replication instance. Min: 5, Max: 6144, Default: 50"
  type        = number
  default     = null
}

variable "repl_instance_auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the replication instance during the maintenance window"
  type        = bool
  default     = null
}

variable "repl_instance_allow_major_version_upgrade" {
  description = "Indicates that major version upgrades are allowed"
  type        = bool
  default     = null
}

variable "repl_instance_apply_immediately" {
  description = "Indicates whether the changes should be applied immediately or during the next maintenance window"
  type        = bool
  default     = null
}

variable "repl_instance_availability_zone" {
  description = "The EC2 Availability Zone that the replication instance will be created in"
  type        = string
  default     = null
}

variable "repl_instance_engine_version" {
  description = "The [engine version](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReleaseNotes.html) number of the replication instance"
  type        = string
  default     = null
}

variable "repl_instance_kms_key_arn" {
  description = "The Amazon Resource Name (ARN) for the KMS key that will be used to encrypt the connection parameters"
  type        = string
  default     = null
}

variable "repl_instance_multi_az" {
  description = "Specifies if the replication instance is a multi-az deployment. You cannot set the `availability_zone` parameter if the `multi_az` parameter is set to `true`"
  type        = bool
  default     = null
}

variable "repl_instance_preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in Universal Coordinated Time (UTC)"
  type        = string
  default     = null
}

variable "repl_instance_publicly_accessible" {
  description = "Specifies the accessibility options for the replication instance"
  type        = bool
  default     = null
}

variable "repl_instance_class" {
  description = "The compute and memory capacity of the replication instance as specified by the replication instance class"
  type        = string
  default     = null
}

variable "repl_instance_id" {
  description = "The replication instance identifier. This parameter is stored as a lowercase string"
  type        = string
  default     = null
}

variable "repl_instance_subnet_group_id" {
  description = "An existing subnet group to associate with the replication instance"
  type        = string
  default     = null
}

variable "repl_instance_vpc_security_group_ids" {
  description = "A list of VPC security group IDs to be used with the replication instance"
  type        = list(string)
  default     = null
}

variable "repl_instance_tags" {
  description = "A map of additional tags to apply to the replication instance"
  type        = map(string)
  default     = {}
}

variable "repl_instance_timeouts" {
  description = "A map of timeouts for replication instance create/update/delete operations"
  type        = map(string)
  default     = {}
}

# Replication Tasks
variable "replication_tasks" {
  description = "Map of objects that define the replication tasks to be created"
  type        = any
  default     = {}
}


# Endpoints
variable "endpoints" {
  description = "Map of objects that define the endpoints to be created"
  type        = any
  default     = {}
}

# Event Subscriptions
variable "event_subscriptions" {
  description = "Map of objects that define the event subscriptions to be created"
  type        = any
  default     = {}
}

variable "event_subscription_timeouts" {
  description = "A map of timeouts for event subscription create/update/delete operations"
  type        = map(string)
  default     = {}
}

# Certificates
variable "certificates" {
  description = "Map of objects that define the certificates to be created"
  type        = map(any)
  default     = {}
}
