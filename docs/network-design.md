# Network Design

IP addressing, subnets, gateways, route tables and routing requirements.
See `README.md` section 5 and 9 for the authoritative values.

## IP Addressing Plan

### VPCs

| VPC | Name | CIDR | Internet Gateway |
|---|---|---|---|
| VPC A | `ewb-vpc-a` | `10.10.0.0/16` | Yes - `ewb-igw-a` |
| VPC B | `ewb-vpc-b` | `10.20.0.0/16` | None |

The CIDRs do not overlap, which is a prerequisite for VPC peering.

### Subnets

| Subnet | Name | VPC | CIDR | Purpose | Public IP auto-assign |
|---|---|---|---|---|---|
| A public | `ewb-a-public` | VPC A | `10.10.1.0/24` | Bastion | On |
| A private | `ewb-a-private` | VPC A | `10.10.2.0/24` | App-A | Off |
| B private | `ewb-b-private` | VPC B | `10.20.1.0/24` | App-B | Off |

### Instances

| Instance | Name | Subnet | Private IPv4 (pinned) | Public IPv4 |
|---|---|---|---|---|
| Bastion | `ewb-bastion` | `ewb-a-public` | `10.10.1.10` | Yes (AWS-assigned) |
| App-A | `ewb-app-a` | `ewb-a-private` | `10.10.2.10` | Not permitted |
| App-B | `ewb-app-b` | `ewb-b-private` | `10.20.1.10` | Not permitted |

Private IPv4 addresses are pinned explicitly at launch time
(`private_ip` in `compute.tf`), so routes, security-group sources and SSH
configuration can rely on the documented values.

## Route Tables

### `ewb-rt-a-public` - associated with `ewb-a-public`

| Destination | Target | Present in | Purpose |
|---|---|---|---|
| `10.10.0.0/16` | `local` | staged + complete | VPC A internal traffic |
| `0.0.0.0/0` | `ewb-igw-a` | staged + complete | Bastion internet connectivity |
| `10.20.0.0/16` | peering connection | **complete only** | Bastion access to VPC B |

### `ewb-rt-a-private` - associated with `ewb-a-private`

| Destination | Target | Present in | Purpose |
|---|---|---|---|
| `10.10.0.0/16` | `local` | staged + complete | VPC A internal traffic |
| `10.20.0.0/16` | peering connection | **complete only** | App-A forward route to App-B |

### `ewb-rt-b-private` - associated with `ewb-b-private`

| Destination | Target | Present in | Purpose |
|---|---|---|---|
| `10.20.0.0/16` | `local` | staged + complete | VPC B internal traffic |
| `10.10.0.0/16` | peering connection | **complete only** | Return route to VPC A |

Each subnet is explicitly associated with its own route table
(`aws_route_table_association` resources exist for all three subnets).

## Routing Requirements (invariants)

1. The AWS-injected local routes are preserved.
2. The peering route target is the actual peering connection, never an IGW.
3. Every intended subnet is explicitly associated with its route table.
4. VPC B's private subnet is never associated with a VPC A route table.
5. VPC B traffic never routes through the Internet Gateway.
6. No NAT gateway exists anywhere in the lab.
7. No `0.0.0.0/0` route exists on either private route table.

## Why routes are needed on both sides

Routing in AWS is per-subnet/per-route-table, and responses follow the
route tables of the **replying** host. A forward route without a return
route (or vice versa) yields asymmetric failure. `aws_route.a_private_peer`
covers VPC A -> VPC B; `aws_route.b_private_peer` covers VPC B -> VPC A;
`aws_route.a_public_peer` lets the bastion (ProxyJump source) reach VPC B.

## Address changes

If any documented value changes intentionally:

1. Update the Terraform variables (`variables.tf` defaults or tfvars).
2. Update every dependent security-group source CIDR (handlers in
   `security.tf` derive `/32` sources from the private-IP variables).
3. Update `scripts/verify-connectivity.sh` targets (or set
   `EWB_APP_A_REMOTE` / `EWB_APP_B_REMOTE`).
4. Update `~/.ssh/config` entries via `scripts/configure-ssh.sh`
   (or the `EWB_APP_A_IP` / `EWB_APP_B_IP` environment overrides).
