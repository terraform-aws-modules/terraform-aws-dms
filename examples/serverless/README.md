# Complete AWS DMS Example

Configuration in this directory creates:

- AWS IAM roles [necessary for AWS DMS](https://aws.amazon.com/premiumsupport/knowledge-center/dms-redshift-connectivity-failures/)
- [AWS DMS subnet group](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS DMS serverless replication configuration](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Serverless.html)
- Two [AWS DMS replication endpoints](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Endpoints.Creating.html) - one `source` and one `target` to migrate data from an Aurora PostgreSQL cluster to Aurora MySQL cluster
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
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

Apache-2.0 Licensed. See [LICENSE](https://github.com/terraform-aws-modules/terraform-aws-dms/blob/master/LICENSE).
