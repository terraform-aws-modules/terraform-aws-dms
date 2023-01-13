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

variable "enable_redshift_target_permissions" {
  description = "Determines whether `redshift.amazonaws.com` is permitted access to assume the `dms-access-for-endpoint` role"
  type        = bool
  default     = false
}

# Subnet group
variable "create_repl_subnet_group" {
  description = "Determines whether the replication subnet group will be created"
  type        = bool
  default     = true
}

variable "repl_subnet_group_name" {
  description = "The name for the replication subnet group. Stored as a lowercase string, must contain no more than 255 alphanumeric characters, periods, spaces, underscores, or hyphens"
  type        = string
  default     = null
}

variable "repl_subnet_group_tags" {
  description = "A map of additional tags to apply to the replication subnet group"
  type        = map(string)
  default     = {}
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

# Replication Instances
variable "replication_instances" {
  description = "Map of objects that define the replication instances to be created"
  type = map(object({
    repl_instance_class                        = string,
    repl_instance_allocated_storage            = optional(number),
    repl_instance_auto_minor_version_upgrade   = optional(bool),
    repl_instance_allow_major_version_upgrade  = optional(bool),
    repl_instance_apply_immediately            = optional(bool),
    repl_instance_engine_version               = optional(string),
    repl_instance_multi_az                     = optional(bool),
    repl_instance_preferred_maintenance_window = optional(string),
    repl_instance_publicly_accessible          = optional(bool),
    repl_instance_vpc_security_group_ids       = optional(list(string)),
    repl_subnet_group_id                       = optional(string),
    repl_conditional_env_filter                = optional(bool)
  }))
  default = {}
}

# Replication Instance Subnet Groups
variable "subnet_groups" {
  description = "Map of objects that define the replication instance subnet groups to be created"
  type        = map(object({
    repl_subnet_group_desc                     = optional(string),
    repl_subnet_ids                            = list(string)
  }))  
  default     = {}
}
