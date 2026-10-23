# Architecture

This document describes the implemented architecture of the EWB VPC Peering
lab. It mirrors the logical architecture in `README.md` section 3; the source
of truth for values is `README.md`.

## Topology overview

```
                      ADMINISTRATOR (local laptop)
                                |
                                | SSH / TCP 22 (only to the bastion)
                         INTERNET GATEWAY (VPC A)
                                |
     +--------------------------------------------------+
     |                  VPC A  10.10.0.0/16             |
     |                                                  |
     |  Public subnet  10.10.1.0/24                     |
     |    ewb-bastion    10.10.1.10  + public IPv4      |
     |                       |                          |
     |                       | SSH                      |
     |  Private subnet 10.10.2.0/24                     |
     |    ewb-app-a      10.10.2.10  no public IPv4     |
     +-------------------|------------------------------+
                         |
                VPC PEERING CONNECTION
                        ewb-a-b-peer (pcx-...)
                         |
     +-------------------|------------------------------+
     |                  VPC B  10.20.0.0/16             |
     |  Private subnet 10.20.1.0/24                     |
     |    ewb-app-b      10.20.1.10  no public IPv4     |
     |                                                  |
     |  No Internet Gateway                             |
     +--------------------------------------------------+
```

## Traffic flows

Administrative access:

```
Laptop -> SSH -> Bastion (10.10.1.10)  --SSH--> App-A (10.10.2.10)
Laptop -> SSH ProxyJump -> Bastion -> (peering) -> App-B (10.20.1.10)
```

Application communication (the lab's core demonstration):

```
App-A (10.10.2.10) -- private IPv4 --> [pcx-...] --> App-B (10.20.1.10)
App-B (10.20.1.10) -- private IPv4 --> [pcx-...] --> App-A (10.10.2.10)
```

## Design properties

* **Non-transitive**: VPC peering only connects the two peered VPCs. It is
  not a transit gateway. Neither VPC gains Internet access through the peer.
* **Bastion-only entry point**: SSH to the bastion is the one internet-facing
  control; both application servers have no public IPv4 address.
* **Bidirectional routing**: forward route in VPC A's route tables, return
  route in VPC B's route table. A route on one side alone is insufficient.
* **Least privilege**: security-group sources are host-specific `/32`
  values (administrator IP, bastion private IP, peer app private IP).

## Implementation mapping

| Logical item | Terraform | Manual equivalent |
|---|---|---|
| VPCs | `aws_vpc.a`, `aws_vpc.b` (`networking.tf`) | VPC console |
| Subnets | `aws_subnet.*` (`networking.tf`) | VPC console |
| Internet Gateway | `aws_internet_gateway.a` | VPC console |
| Route tables + associations | `aws_route_table.*`, `aws_route_table_association.*` | VPC console |
| Peering | `aws_vpc_peering_connection.a_b` (`main.tf`) | VPC console |
| Routes to the peering | `aws_route.*` (`networking.tf`) | VPC console |
| Security groups | `aws_security_group.*` (`security.tf`) | VPC console |
| Instances | `aws_instance.*` (`compute.tf`) | EC2 console |

## Deployment modes (README section 8)

* **Mode 1 - staged**: Terraform `deployment_mode = "staged"` deploys
  everything *except* the peering connection and the peering routes. The
  required baseline ping failure (Tests 1) can then be captured honestly.
* **Mode 2 - complete**: `deployment_mode = "complete"` adds the peering
  connection (`ewb-a-b-peer`) and the three peering routes
  (public subnet of VPC A, private subnet A, private subnet B) without
  touching the instances, subnets or security groups.

Switching modes is an explicit `terraform apply` step; nothing deploys
automatically. The staged mode never "accidentally" establishes peering or
peer routes before the baseline test.
