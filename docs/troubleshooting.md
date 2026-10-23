# Troubleshooting

From README section 17. Investigate unexpected results before recording any
evidence. `scripts/validate-aws-resources.sh` automates most of the checks
below without modifying anything.

## Problem 1: bastion SSH times out

Check, in order:

1. The bastion instance is running and passed status checks.
2. The **current** public IPv4 is used (IPs change across restarts):
   `terraform output -raw bastion_public_ip`.
3. The public subnet is associated with `ewb-rt-a-public`.
4. `0.0.0.0/0` targets the **attached** Internet Gateway:
   `./scripts/validate-aws-resources.sh --mode staged` checks this.
5. `ewb-sg-bastion` allows TCP 22 from your **current** public IP `/32`.
   Get it with `curl -s https://checkip.amazonaws.com`; if it changed,
   update `admin_cidr` (or the console rule) and re-apply.
6. Network ACLs still permit inbound 22 and the **ephemeral** return ports.

## Problem 2: App-A SSH fails

1. App-A runs and has private IP `10.10.2.10`.
2. App-A uses `ewb-sg-app-a`, whose SSH source is `10.10.1.10/32`.
3. The correct key pair and username `ec2-user` are used (Amazon Linux 2023).
4. The local SSH config resolves `ewb-app-a` with `ProxyJump ewb-bastion`
   (`ssh -G ewb-app-a | grep hostname`).

## Problem 3: App-B SSH fails

1. Peering status is `active`.
2. The **public** route table of the bastion subnet contains
   `10.20.0.0/16 -> peering connection`; the proxy-hop from the bastion has
   no workable path without this route.
3. `ewb-rt-b-private` has the return route `10.10.0.0/16 -> peering`.
4. `ewb-sg-app-b` allows TCP 22 from `10.10.1.10/32`.
5. App-B has private IP `10.20.1.10`; the key and `ec2-user` are correct.

## Problem 4: ping fails after peering has been configured

Check in this order (this is exactly what Test 6 exploits):

1. Peering connection is `active`.
2. The route table **associated with App-A's subnet** has
   `10.20.0.0/16 -> peering`.
3. `ewb-rt-b-private` has the return route `10.10.0.0/16 -> peering`.
4. `ewb-sg-app-a` allows ICMP echo from `10.20.1.10/32`.
5. `ewb-sg-app-b` allows ICMP echo from `10.10.2.10/32`.
6. Both instances actually hold the pinned private IPs.
7. Network ACLs have not been changed from the default allow rules.
8. Both instances run and respond (e.g. via SSH).

## Problem 5: VPC peering cannot be created

Standard VPC peering requires non-overlapping IPv4 CIDRs. Primary CIDRs:
VPC A `10.10.0.0/16`, VPC B `10.20.0.0/16`. Also inspect **additional/secondary
CIDR associations** of both VPCs; a secondary block can still overlap.

## Problem 6: Permission denied (public key)

1. The right private key is used (`~/.ssh/ewb-lab.pem`, permissions 400).
2. The instance was launched with the `ewb-lab` key pair.
3. Username is `ec2-user`.
4. `~/.ssh/config` `IdentityFile` points to the same key.

A public-key failure is an **authentication** problem, not a routing one -
fix auth first, then judge connectivity.

## Problem 7: private instances cannot download packages

By design, the private subnets have no internet egress (no NAT). A failed
package install is **not** evidence of a broken peering connection. This lab
requires no package installation on the app servers.

## Problem 8: Terraform shows unexpected changes

1. Correct profile and region are selected (`--profile`, `AWS_REGION`).
2. The correct state file is used (check `terraform workspace list` /
   backend config).
3. Resources were not modified manually outside Terraform (console edits
   drift from state).
4. Configured values match reality (compare outputs with console values).
5. The AMI is available in the target region - the configuration looks the
   AMI up region-aware, so a pinned `ami_id` stale for the region is the
   usual suspect.

Review the plan carefully before applying.

## Problem 9 (scripts): "SSH alias is not configured" / BatchMode failures

Run `scripts/configure-ssh.sh --bastion-ip <IP>` and inspect
`~/.ssh/config`. `verify-connectivity.sh` uses `BatchMode=yes`, so
interactive key-selection prompts are intentionally unavailable.

## Problem 10 (scripts): `ssh -G` unsupported

`ssh -G` needs OpenSSH >= 7.3 (macOS and Linux defaultOpenSSH since ~2017
support it). Update the OS OpenSSH client if needed.
