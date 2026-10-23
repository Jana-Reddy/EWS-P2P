# Security Model

Least-privilege design of the EWB VPC Peering lab (README sections 10, 18).

## Security Groups

Security groups are stateful: return traffic for an allowed outbound flow is
allowed automatically, so only inbound rules are defined. Outbound remains
allow-all on purpose for this educational lab.

### `ewb-sg-bastion` (VPC A)

| Proto | Port | Source | Purpose |
|---|---|---|---|
| TCP | 22 | administrator's public IPv4 `/32` (`var.admin_cidr`) | SSH entry point |

SSH is **never** open to `0.0.0.0/0`. If the administrator's IP changes,
update `admin_cidr` and re-apply.

### `ewb-sg-app-a` (VPC A)

| Proto | Port/Type | Source | Purpose |
|---|---|---|---|
| TCP | 22 | `10.10.1.10/32` (bastion private IP) | SSH from bastion (ProxyJump) |
| ICMP | type 8, code 0 (echo request) | `10.20.1.10/32` (App-B) | ping from App-B |

### `ewb-sg-app-b` (VPC B)

| Proto | Port/Type | Source | Purpose |
|---|---|---|---|
| TCP | 22 | `10.10.1.10/32` (bastion private IP) | SSH from bastion (ProxyJump) |
| ICMP | type 8, code 0 (echo request) | `10.10.2.10/32` (App-A) | ping from App-A |

Why the sources are the bastion's **private** IP: when the bastion opens an
SSH connection to an app server, packets leave its ENI with the private
source address `10.10.1.10`; the public IP is a NAT mapping that exists only
on the internet path.

The ICMP rule in `ewb-sg-app-b` is the one used for the controlled failure
test: removing it stops App-A -> App-B pings; restoring it resumes them
(Test 6, README section 13). Nothing in this repository removes it
automatically.

Default (non-default) network ACLs remain untouched unless the lab is
explicitly extended to stateless ACL design.

## Key management

* One key pair, `ewb-lab`, is used by all three instances.
* The **private key stays on the administrator's machine**
  (`~/.ssh/ewb-lab.pem`, `chmod 400`). It is never uploaded to AWS (except
  its public half at creation), never copied to the bastion, never committed.
* `.gitignore` excludes `*.pem`, `*.key` and id/ed25519-style names.
* SSH access to app servers uses **ProxyJump**, so the agent/key never needs
  to live on the bastion: `~/.ssh/config` lists `ProxyJump ewb-bastion`.

## Credentials

* No AWS credentials are stored anywhere in this repository.
* Terraform uses the standard AWS credential chain (profile, env, SSO).
* Terraform state files are excluded from git (`*.tfstate*`) because state
  can contain sensitive metadata.

## What this lab is NOT

This is an educational networking lab, not a production architecture.
Representative production improvements (all *optional extensions*, none
implemented here - do not claim them as completed features):

* AWS Systems Manager Session Manager instead of direct SSH exposure.
* Least-privilege IAM roles on the instances.
* Centralised logging / audit trails and stricter egress SG rules.
* Explicitly designed network ACLs where required.
* Encrypted managed remote state with access controls.
* Automated policy validation and patch management.
