# Cleanup Procedure

Cleanup is mandatory after all evidence has been collected.
Authorization first: nothing here is executed automatically by tooling.

## If Terraform manages the infrastructure

Confirm which state is selected. **Do not continue** if the state manages
unrelated infrastructure.

```bash
terraform workspace list   # (optional, if workspaces are used)
terraform plan -destroy    # REVIEW carefully - every line is substance
```

Manual created resources (e.g. a console-made key pair used by a Terraform
instance) are **not** captured by the state; delete them by hand as below.

If the plan contains only intended lab resources, explicitly:

```bash
terraform destroy          # nothing destructive is automated here
```

`destroy` removes instances, SGs, routes, route tables, associations,
subnets, IGW, peering and the VPCs (order handled by Terraform).
If `create_key_pair = true` was used, the EC2 key pair is removed too.

## If resources were created manually (console / AWS CLI)

Follow README section 22 order. Remove only lab resources (name prefix
`ewb-` / tags `Project=EWB-VPC-Peering`):

1. Terminate instances: `ewb-bastion`, `ewb-app-a`, `ewb-app-b`.
2. Verify lab EBS volumes are deleted (delete_on_termination).
3. Remove lab snapshots no longer needed (none expected).
4. Release any Elastic IP allocated for the lab (default flow creates none).
5. Delete the VPC peering connection.
6. Remove the peer routes (route-tables `ewb-rt-a-public`,
   `ewb-rt-a-private`, `ewb-rt-b-private`).
7. Delete the security groups (only after their ENIs are gone).
8. Delete the three subnets.
9. Delete the three custom route tables.
10. Detach `ewb-igw-a` from VPC A, then delete the gateway.
11. Delete VPC A and VPC B.
12. Delete the unused lab key pair if appropriate.
13. Verify no project resources remain.

## Aftermath checks

* Check AWS **Billing** after cleanup - usage data may lag by hours.
* `./scripts/validate-aws-resources.sh --mode complete` should end in FAIL
  for every deleted resource - a convenient negative confirmation.
* Keep evidence (screenshots/outputs) in `evidence/`; evidence is source
  material for the report and should be committed.
* Remove local test files (e.g. no stray key copies anywhere).
