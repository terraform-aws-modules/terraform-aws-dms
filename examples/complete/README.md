# Complete AWS DMS Example

Configuration in this directory creates:

- AWS IAM roles [necessary for AWS DMS](https://aws.amazon.com/premiumsupport/knowledge-center/dms-redshift-connectivity-failures/)
- [AWS DMS subnet group](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS DMS replication instance](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.Creating.html)
- Two [AWS DMS replication endpoints](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Endpoints.Creating.html) - one `source` and one `target` to migrate data from an Aurora PostgreSQL cluster to Aurora MySQL cluster
- [AWS DMS replication task](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.Creating.html)
- Two [AWS DMS event subscriptions](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Events.html) - one for the replication instance, and one for the replication task
- Necessary supporting resources to demonstrate the capabilities of the module (VPC, Aurora clusters, security groups, etc.)

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Note that this example may create resources which will incur monetary charges on your AWS bill. Run `terraform destroy` when you no longer need these resources.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.17 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.17 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dms_aurora_postgresql_aurora_mysql"></a> [dms\_aurora\_postgresql\_aurora\_mysql](#module\_dms\_aurora\_postgresql\_aurora\_mysql) | ../.. | n/a |
| <a name="module_dms_default"></a> [dms\_default](#module\_dms\_default) | ../.. | n/a |
| <a name="module_dms_disabled"></a> [dms\_disabled](#module\_dms\_disabled) | ../.. | n/a |
| <a name="module_msk_cluster"></a> [msk\_cluster](#module\_msk\_cluster) | clowdhaus/msk-kafka-cluster/aws | ~> 1.0 |
| <a name="module_rds_aurora"></a> [rds\_aurora](#module\_rds\_aurora) | terraform-aws-modules/rds-aurora/aws | ~> 6.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 3.1 |
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | terraform-aws-modules/security-group/aws | ~> 4.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.0 |
| <a name="module_vpc_endpoint_security_group"></a> [vpc\_endpoint\_security\_group](#module\_vpc\_endpoint\_security\_group) | terraform-aws-modules/security-group/aws | ~> 4.0 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.s3_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.secretsmanager_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_kms_key.aurora_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_rds_cluster_parameter_group.postgresql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_s3_object.hr_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_secretsmanager_secret.aurora_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_version.aurora_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.msk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_sns_topic.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [random_pet.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

No inputs.

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

Apache-2.0 Licensed. See [LICENSE](https://github.com/terraform-aws-modules/terraform-aws-dms/blob/master/LICENSE).
