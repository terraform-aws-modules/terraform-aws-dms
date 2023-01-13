# AWS DMS Terraform module

Terraform module which creates AWS DMS (Database Migration Service) resources.

## Usage

See [`examples`](https://github.com/terraform-aws-modules/terraform-aws-dms/tree/master/examples) directory for working examples to reference:

```hcl
module "database_migration_service" {
  source  = "terraform-aws-modules/dms/aws"
  version = "~> 1.0"

  # Subnet group
  subnet_groups = {
    "example" = {
      repl_subnet_group_desc = "DMS Subnet group"
      repl_subnet_ids        = ["subnet-1fe3d837", "subnet-129d66ab", "subnet-1211eef5"]
    }
  }

  # Instance
  replication_instances = {
      "example" = {
         repl_instance_class                        = "dms.t3.large"
         repl_instance_allocated_storage            = 64
         repl_instance_auto_minor_version_upgrade   = true
         repl_instance_allow_major_version_upgrade  = true
         repl_instance_apply_immediately            = true
         repl_instance_engine_version               = "3.4.5"
         repl_instance_multi_az                     = true
         repl_instance_preferred_maintenance_window = "sun:10:30-sun:14:30"
         repl_instance_publicly_accessible          = false
         repl_instance_vpc_security_group_ids       = ["sg-12345678"]
         repl_subnet_group_id                       = "example"
         repl_conditional_env_filter                = true
	  }
  }

  endpoints = {
    source = {
      database_name               = "example"
      endpoint_id                 = "example-source"
      endpoint_type               = "source"
      engine_name                 = "aurora-postgresql"
      extra_connection_attributes = "heartbeatFrequency=1;"
      username                    = "postgresqlUser"
      password                    = "youShouldPickABetterPassword123!"
      port                        = 5432
      server_name                 = "dms-ex-src.cluster-abcdefghijkl.us-east-1.rds.amazonaws.com"
      ssl_mode                    = "none"
      tags                        = { EndpointType = "source" }
    }

    destination = {
      database_name = "example"
      endpoint_id   = "example-destination"
      endpoint_type = "target"
      engine_name   = "aurora"
      username      = "mysqlUser"
      password      = "passwordsDoNotNeedToMatch789?"
      port          = 3306
      server_name   = "dms-ex-dest.cluster-abcdefghijkl.us-east-1.rds.amazonaws.com"
      ssl_mode      = "none"
      tags          = { EndpointType = "destination" }
    }
  }

  replication_tasks = {
    cdc_ex = {
      replication_task_id       = "example-cdc"
      migration_type            = "cdc"
      replication_task_settings = file("task_settings.json")
      table_mappings            = file("table_mappings.json")
      source_endpoint_key       = "source"
      target_endpoint_key       = "destination"
      tags                      = { Task = "PostgreSQL-to-MySQL" }
    }
  }

  event_subscriptions = {
    instance = {
      name                             = "instance-events"
      enabled                          = true
      instance_event_subscription_keys = ["example"]
      source_type                      = "replication-instance"
      sns_topic_arn                    = "arn:aws:sns:us-east-1:012345678910:example-topic"
      event_categories                 = [
        "failure",
        "creation",
        "deletion",
        "maintenance",
        "failover",
        "low storage",
        "configuration change"
      ]
    }
    task = {
      name                         = "task-events"
      enabled                      = true
      task_event_subscription_keys = ["cdc_ex"]
      source_type                  = "replication-task"
      sns_topic_arn                = "arn:aws:sns:us-east-1:012345678910:example-topic"
      event_categories             = [
        "failure",
        "state change",
        "creation",
        "deletion",
        "configuration change"
      ]
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

### Combinations

Within DMS you can have multiple combinations of resources depending on your use case. For example (not an exhaustive list of possible combinations):
#### Simple
  - One source endpoint
  - One target/destination endpoint
  - One replication task
  - Two event subscriptions
    - Replication instance event subscription
    - Replication task event subscriptions

<p align="center">
  <img src="https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-dms/master/.github/images/dms_simple.png" alt="DMS Simple" width="100%">
</p>

#### Multiple endpoints, multiple tasks
  - Two source endpoints
  - Three target/destination endpoints
  - Three replication tasks (source1 -> target1, source2 -> target2, source1 -> targe3)
  - Four event subscriptions
    - Replication instance event subscription
    - Replication task event subscription for each task listed above

<p align="center">
  <img src="https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-dms/master/.github/images/dms_complex.png" alt="DMS Complex" width="100%">
</p>

In order to accommodate a flexible, multi-resource combinatorial module, keys and maps are used for cross-referencing resources created within the module.

Given the following example (not complete, only showing the relevant attributes):

```hcl
module "database_migration_service" {
  source  = "terraform-aws-modules/dms/aws"
  version = "~> 1.0"

  endpoints = {
    # These keys are used to map endpoints within task definitions by this key `source1`
    source1 = {
      endpoint_type = "source"
      ...
    }

    destination1 = {
      endpoint_type = "target"
      ...
    }

    destination2 = {
      endpoint_type = "target"
      ...
    }
  }
```

To create multiple replication instances, you provide multiple keys to the `replication_instances` map:

```hcl
  replication_instances = {
    rep_instance1 = {
	  repl_instance_class = "dms.t3.large"
      ...
    }
    rep_instance2 = {
	  repl_instance_class = "dms.t3.large"	
      ...
    }
  }
```

To create multiple replication instance subnet groups, you provide multiple keys to the `subnet_groups` map:

```hcl
  subnet_groups = {
    subnet_group1 = {
	  repl_subnet_ids = ["subnet-1fe3d837", "subnet-129d66ab", "subnet-1211eef5"]
      ...
    }
    subnet_group1 = {
	  repl_subnet_ids = ["subnet-2fe3d837", "subnet-229d66ab", "subnet-2211eef5"]
      ...
    }
  }
```

To create replication tasks, you simply reference the relevant keys from the `endpoints` map in the `source_endpoint_key`/`target_endpoint_key` fields:

```hcl
  ...

  replication_tasks = {
    src1_dest1 = {
      ...
      source_endpoint_key = "source1"
      target_endpoint_key = "destination1"
    }
    src1_dest2 = {
      ...
      source_endpoint_key = "source1"
      target_endpoint_key = "destination2"
    }
  }

  ...
```

Continuing the same lookup patter, to create event subscriptions, you simply reference the replication instance ID in the `instance_event_subscription_keys`field when subscribing to instance notifications, or the `replication_tasks` keys in the `task_event_subscription_keys` to subscribe to the tasks notifications (all or only select keys for select tasks):

```hcl
  ...

  event_subscriptions = {
    instance = {
      instance_event_subscription_keys = ["readme-example"]
      ...
    }
    task = {
      task_event_subscription_keys = ["src1_dest1", "src1_dest2]
      ...
    }
  }

  ...
```

### Tasks

Tasks are the "jobs" that perform the necessary actions of migrating from `source` to `target`, including any transformations and/or mappings of the data in transit. Tasks are largely controlled by [task settings](http://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.CustomizingTasks.TaskSettings.html) that are defined in a JSON document.

<p align="center">
  <img src="https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-dms/master/.github/images/replication_task.png" alt="Replication Task" width="100%">
</p>

#### [Example task settings JSON document](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.CustomizingTasks.TaskSettings.Saving.html):
```json

{
  "TargetMetadata": {
    "TargetSchema": "",
    "SupportLobs": true,
    "FullLobMode": false,
    "LobChunkSize": 64,
    "LimitedSizeLobMode": true,
    "LobMaxSize": 32,
    "BatchApplyEnabled": true
  },
  "FullLoadSettings": {
    "TargetTablePrepMode": "DO_NOTHING",
    "CreatePkAfterFullLoad": false,
    "StopTaskCachedChangesApplied": false,
    "StopTaskCachedChangesNotApplied": false,
    "MaxFullLoadSubTasks": 8,
    "TransactionConsistencyTimeout": 600,
    "CommitRate": 10000
  },
  "Logging": {
    "EnableLogging": false
  },
  "ControlTablesSettings": {
    "ControlSchema":"",
    "HistoryTimeslotInMinutes":5,
    "HistoryTableEnabled": false,
    "SuspendedTablesTableEnabled": false,
    "StatusTableEnabled": false
  },
  "StreamBufferSettings": {
    "StreamBufferCount": 3,
    "StreamBufferSizeInMB": 8
  },
  "ChangeProcessingTuning": {
    "BatchApplyPreserveTransaction": true,
    "BatchApplyTimeoutMin": 1,
    "BatchApplyTimeoutMax": 30,
    "BatchApplyMemoryLimit": 500,
    "BatchSplitSize": 0,
    "MinTransactionSize": 1000,
    "CommitTimeout": 1,
    "MemoryLimitTotal": 1024,
    "MemoryKeepTime": 60,
    "StatementCacheSize": 50
  },
  "ChangeProcessingDdlHandlingPolicy": {
    "HandleSourceTableDropped": true,
    "HandleSourceTableTruncated": true,
    "HandleSourceTableAltered": true
  },
  "ErrorBehavior": {
    "DataErrorPolicy": "LOG_ERROR",
    "DataTruncationErrorPolicy":"LOG_ERROR",
    "DataErrorEscalationPolicy":"SUSPEND_TABLE",
    "DataErrorEscalationCount": 50,
    "TableErrorPolicy":"SUSPEND_TABLE",
    "TableErrorEscalationPolicy":"STOP_TASK",
    "TableErrorEscalationCount": 50,
    "RecoverableErrorCount": 0,
    "RecoverableErrorInterval": 5,
    "RecoverableErrorThrottling": true,
    "RecoverableErrorThrottlingMax": 1800,
    "ApplyErrorDeletePolicy":"IGNORE_RECORD",
    "ApplyErrorInsertPolicy":"LOG_ERROR",
    "ApplyErrorUpdatePolicy":"LOG_ERROR",
    "ApplyErrorEscalationPolicy":"LOG_ERROR",
    "ApplyErrorEscalationCount": 0,
    "FullLoadIgnoreConflicts": true
  }
}
```

## Examples

Examples codified under the [`examples`](https://github.com/terraform-aws-modules/terraform-aws-dms/tree/master/examples) are intended to give users references for how to use the module(s) as well as testing/validating changes to the source code of the module. If contributing to the project, please be sure to make any appropriate updates to the relevant examples to allow maintainers to test your changes and to keep the examples up to date for users. Thank you!

- [Complete](https://github.com/terraform-aws-modules/terraform-aws-dms/tree/master/examples/complete)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.17 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >=0.7.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.17 |
| <a name="provider_time"></a> [time](#provider\_time) | >=0.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dms_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_certificate) | resource |
| [aws_dms_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_endpoint) | resource |
| [aws_dms_event_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_event_subscription) | resource |
| [aws_dms_replication_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_instance) | resource |
| [aws_dms_replication_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_subnet_group) | resource |
| [aws_dms_replication_task.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_task) | resource |
| [aws_iam_role.dms_access_for_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dms_cloudwatch_logs_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dms_vpc_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [time_sleep.wait_for_dependency_resources](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_iam_policy_document.dms_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dms_assume_role_redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificates"></a> [certificates](#input\_certificates) | Map of objects that define the certificates to be created | `map(any)` | `{}` | no |
| <a name="input_create"></a> [create](#input\_create) | Determines whether resources will be created | `bool` | `true` | no |
| <a name="input_create_iam_roles"></a> [create\_iam\_roles](#input\_create\_iam\_roles) | Determines whether the required [DMS IAM resources](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Security.html#CHAP_Security.APIRole) will be created | `bool` | `true` | no |
| <a name="input_create_repl_subnet_group"></a> [create\_repl\_subnet\_group](#input\_create\_repl\_subnet\_group) | Determines whether the replication subnet group will be created | `bool` | `true` | no |
| <a name="input_enable_redshift_target_permissions"></a> [enable\_redshift\_target\_permissions](#input\_enable\_redshift\_target\_permissions) | Determines whether `redshift.amazonaws.com` is permitted access to assume the `dms-access-for-endpoint` role | `bool` | `false` | no |
| <a name="input_endpoints"></a> [endpoints](#input\_endpoints) | Map of objects that define the endpoints to be created | `any` | `{}` | no |
| <a name="input_event_subscription_timeouts"></a> [event\_subscription\_timeouts](#input\_event\_subscription\_timeouts) | A map of timeouts for event subscription create/update/delete operations | `map(string)` | `{}` | no |
| <a name="input_event_subscriptions"></a> [event\_subscriptions](#input\_event\_subscriptions) | Map of objects that define the event subscriptions to be created | `any` | `{}` | no |
| <a name="input_iam_role_permissions_boundary"></a> [iam\_role\_permissions\_boundary](#input\_iam\_role\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the role | `string` | `null` | no |
| <a name="input_iam_role_tags"></a> [iam\_role\_tags](#input\_iam\_role\_tags) | A map of additional tags to apply to the DMS IAM roles | `map(string)` | `{}` | no |
| <a name="input_repl_instance_tags"></a> [repl\_instance\_tags](#input\_repl\_instance\_tags) | A map of additional tags to apply to the replication instance | `map(string)` | `{}` | no |
| <a name="input_repl_instance_timeouts"></a> [repl\_instance\_timeouts](#input\_repl\_instance\_timeouts) | A map of timeouts for replication instance create/update/delete operations | `map(string)` | `{}` | no |
| <a name="input_repl_subnet_group_tags"></a> [repl\_subnet\_group\_tags](#input\_repl\_subnet\_group\_tags) | A map of additional tags to apply to the replication subnet group | `map(string)` | `{}` | no |
| <a name="input_replication_instances"></a> [replication\_instances](#input\_replication\_instances) | A map of objects that define the replication instances to be created | <pre>map(object({<br>  repl_instance_class = string,<br>  repl_instance_allocated_storage = optional(number),<br>  repl_instance_auto_minor_version_upgrade = optional(bool),<br>  repl_instance_allow_major_version_upgrade = optional(bool),<br>  repl_instance_apply_immediately = optional(bool),<br>  repl_instance_engine_version = optional(string),<br>  repl_instance_multi_az = optional(bool),<br>  repl_instance_preferred_maintenance_window = optional(string),<br>  repl_instance_publicly_accessible = optional(bool),<br>  repl_instance_vpc_security_group_ids = optional(list(string)),<br>  repl_subnet_group_id = optional(string),<br>  repl_conditional_env_filter = optional(bool)<br>}</pre> | `{}` | no |
| <a name="input_replication_tasks"></a> [replication\_tasks](#input\_replication\_tasks) | Map of objects that define the replication tasks to be created | `any` | `{}` | no |
| <a name="subnet_groups"></a> [subnet\_groups](#input\_subnet\_groups) | A map of objects that define the replication instance subnet groups to be created | <pre>map(object({<br>  repl_subnet_group_desc = optional(string),<br>  repl_subnet_ids = list(string)<br>}</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to use on all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificates"></a> [certificates](#output\_certificates) | A map of maps containing the certificates created and their full output of attributes and values |
| <a name="output_dms_access_for_endpoint_iam_role_arn"></a> [dms\_access\_for\_endpoint\_iam\_role\_arn](#output\_dms\_access\_for\_endpoint\_iam\_role\_arn) | Amazon Resource Name (ARN) specifying the role |
| <a name="output_dms_access_for_endpoint_iam_role_id"></a> [dms\_access\_for\_endpoint\_iam\_role\_id](#output\_dms\_access\_for\_endpoint\_iam\_role\_id) | Name of the IAM role |
| <a name="output_dms_access_for_endpoint_iam_role_unique_id"></a> [dms\_access\_for\_endpoint\_iam\_role\_unique\_id](#output\_dms\_access\_for\_endpoint\_iam\_role\_unique\_id) | Stable and unique string identifying the role |
| <a name="output_dms_cloudwatch_logs_iam_role_arn"></a> [dms\_cloudwatch\_logs\_iam\_role\_arn](#output\_dms\_cloudwatch\_logs\_iam\_role\_arn) | Amazon Resource Name (ARN) specifying the role |
| <a name="output_dms_cloudwatch_logs_iam_role_id"></a> [dms\_cloudwatch\_logs\_iam\_role\_id](#output\_dms\_cloudwatch\_logs\_iam\_role\_id) | Name of the IAM role |
| <a name="output_dms_cloudwatch_logs_iam_role_unique_id"></a> [dms\_cloudwatch\_logs\_iam\_role\_unique\_id](#output\_dms\_cloudwatch\_logs\_iam\_role\_unique\_id) | Stable and unique string identifying the role |
| <a name="output_dms_vpc_iam_role_arn"></a> [dms\_vpc\_iam\_role\_arn](#output\_dms\_vpc\_iam\_role\_arn) | Amazon Resource Name (ARN) specifying the role |
| <a name="output_dms_vpc_iam_role_id"></a> [dms\_vpc\_iam\_role\_id](#output\_dms\_vpc\_iam\_role\_id) | Name of the IAM role |
| <a name="output_dms_vpc_iam_role_unique_id"></a> [dms\_vpc\_iam\_role\_unique\_id](#output\_dms\_vpc\_iam\_role\_unique\_id) | Stable and unique string identifying the role |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | A map of maps containing the endpoints created and their full output of attributes and values |
| <a name="output_event_subscriptions"></a> [event\_subscriptions](#output\_event\_subscriptions) | A map of maps containing the event subscriptions created and their full output of attributes and values |
| <a name="output_replication_instance_arn"></a> [replication\_instance\_arn](#output\_replication\_instance\_arn) | The Amazon Resource Name (ARN) of the replication instance |
| <a name="output_replication_instance_private_ips"></a> [replication\_instance\_private\_ips](#output\_replication\_instance\_private\_ips) | A list of the private IP addresses of the replication instance |
| <a name="output_replication_instance_public_ips"></a> [replication\_instance\_public\_ips](#output\_replication\_instance\_public\_ips) | A list of the public IP addresses of the replication instance |
| <a name="output_replication_instance_tags_all"></a> [replication\_instance\_tags\_all](#output\_replication\_instance\_tags\_all) | A map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block |
| <a name="output_replication_subnet_group_id"></a> [replication\_subnet\_group\_id](#output\_replication\_subnet\_group\_id) | The ID of the subnet group |
| <a name="output_replication_tasks"></a> [replication\_tasks](#output\_replication\_tasks) | A map of maps containing the replication tasks created and their full output of attributes and values |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## License

Apache-2.0 Licensed. See [LICENSE](https://github.com/terraform-aws-modules/terraform-aws-dms/blob/master/LICENSE).
