# AWS VPC Peering Project

Secure Private Communication Between Two Amazon VPCs
(EWB Courses - Cloud Networking / AWS Architect Associate lab)

**This README is the source of truth for the project.** Section numbers below
(matching the original project workbook) are referenced from the docs and
scripts.

---

## 1. Project Overview

The AWS VPC Peering Project demonstrates how to establish private network
connectivity between two isolated Amazon Virtual Private Clouds (VPCs) using
an AWS VPC peering connection.

The project consists of two VPCs, three EC2 instances, custom route tables,
security groups, an Internet Gateway, and one VPC peering connection.

The first VPC contains a public bastion host and a private application
server. The second VPC contains another private application server.

The application servers communicate using private IPv4 addresses through the
peering connection. Administrative SSH access to both private instances is
routed through the bastion host.

The project also demonstrates network isolation, least-privilege security
rules, bidirectional routing, connectivity testing, controlled failure
testing, troubleshooting, and infrastructure cleanup.

### Primary Objectives

* Create two non-overlapping VPCs.
* Configure public and private subnets.
* Deploy three EC2 instances.
* Keep both application servers private.
* Establish a VPC peering connection.
* Configure routes in both directions.
* Restrict SSH and ICMP access through security groups.
* Access private instances using SSH ProxyJump.
* Demonstrate connectivity before and after peering.
* Perform a controlled security-group failure test.
* Document the architecture, implementation, testing, and cleanup.

---

## 2. Project Requirements

### Functional Requirements

The completed project must satisfy the following requirements:

1. VPC A and VPC B must use different, non-overlapping IPv4 CIDR blocks.
2. VPC A must contain one public subnet and one private subnet.
3. VPC B must contain one private subnet.
4. The bastion host must be deployed in VPC A's public subnet.
5. App-A must be deployed in VPC A's private subnet.
6. App-B must be deployed in VPC B's private subnet.
7. App-A and App-B must not have public IPv4 addresses.
8. A VPC peering connection must connect VPC A and VPC B.
9. Both private route tables must contain the appropriate peering routes.
10. VPC A's public route table must allow the bastion to reach VPC B through peering.
11. Security groups must permit only the required administrative and ICMP traffic.
12. App-A and App-B must communicate using their private IP addresses.
13. Both private instances must be accessible through the bastion.
14. Removing the destination ICMP rule must interrupt ping connectivity.
15. Restoring the rule must restore connectivity.
16. All resources created for the lab must be removable after evidence collection.

### Non-Functional Requirements

* Secure configuration by default.
* Reproducible infrastructure deployment.
* Clear resource naming.
* Explicit subnet-to-route-table associations.
* No unnecessary NAT gateways.
* No hardcoded AWS credentials.
* No private keys committed to version control.
* No unrestricted public SSH access.
* Clear deployment, validation, troubleshooting, and cleanup instructions.

---

## 3. Architecture

### Logical Architecture

```
                         ADMINISTRATOR
                           LOCAL LAPTOP
                               |
                               | SSH / TCP 22
                               |
                        INTERNET GATEWAY
                               |
      +--------------------------------------------------+
      |                     VPC A                        |
      |                10.10.0.0/16                      |
      |  +-------------------------------------------+   |
      |  | Public Subnet: 10.10.1.0/24               |   |
      |  |  Bastion Host                             |   |
      |  |  Private IP: 10.10.1.10                   |   |
      |  |  Public IPv4: AWS assigned                |   |
      |  +-----------------|-------------------------+   |
      |                    | SSH                         |
      |  +-----------------|-------------------------+   |
      |  | Private Subnet: 10.10.2.0/24              |   |
      |  |  App-A  10.10.2.10  (no public IPv4)      |   |
      |  +-----------------|-------------------------+   |
      +--------------------|-----------------------------+
                           |
                 VPC PEERING CONNECTION  pcx-...
                           |
      +--------------------|-----------------------------+
      |                                VPC B             |
      |                           10.20.0.0/16           |
      |  +-------------------------------------------+   |
      |  | Private Subnet: 10.20.1.0/24              |   |
      |  |  App-B  10.20.1.10  (no public IPv4)      |   |
      |  +-------------------------------------------+   |
      |            No Internet Gateway                   |
      +--------------------------------------------------+
```

### Administrative Traffic

```
Local Laptop
    | SSH to Bastion Public IPv4
    v
Bastion: 10.10.1.10  -- SSH through private network -->  App-A: 10.10.2.10

Local Laptop
    | SSH ProxyJump
    v
Bastion: 10.10.1.10  -- SSH through VPC peering -->  App-B: 10.20.1.10
```

### Application Traffic

```
App-A: 10.10.2.10  -- private IPv4 --> [VPC Peering] --> App-B: 10.20.1.10
```

> **Important:** VPC peering does not automatically provide internet access
> to VPC B. The peering connection is not a transit gateway, and VPC peering
> is non-transitive.

---

## 4. Technology Stack

| Technology | Purpose |
|---|---|
| Amazon VPC | Isolated virtual networks |
| Amazon EC2 | Bastion and application instances |
| Amazon VPC Peering | Private connectivity between VPCs |
| Internet Gateway | Internet connectivity for the bastion subnet |
| Route Tables | Direct traffic between networks |
| Security Groups | Stateful instance-level traffic filtering |
| Amazon Linux 2023 | Operating system for EC2 instances |
| OpenSSH | Remote administration |
| Terraform | Optional infrastructure automation |
| Git | Source control |
| OpenCode | AI-assisted implementation and validation |

### AWS Region

Default region: **ap-south-1** (Asia Pacific, Mumbai).

All resources are deployed in the same AWS account and region unless the
project is deliberately extended.

---

## 5. IP Addressing Plan

Use the following addressing plan without modification unless there is a
documented reason to change it.

### VPC Configuration

| Resource | Name | CIDR |
|---|---|---|
| VPC A | `ewb-vpc-a` | `10.10.0.0/16` |
| VPC B | `ewb-vpc-b` | `10.20.0.0/16` |

The CIDR ranges do not overlap, which is required for ordinary VPC peering
between these networks.

### Subnet Configuration

| Resource | Name | VPC | CIDR | Purpose |
|---|---|---|---|---|
| Public subnet A | `ewb-a-public` | VPC A | `10.10.1.0/24` | Bastion |
| Private subnet A | `ewb-a-private` | VPC A | `10.10.2.0/24` | App-A |
| Private subnet B | `ewb-b-private` | VPC B | `10.20.1.0/24` | App-B |

### EC2 Configuration

| Instance | Name | Subnet | Private IPv4 | Public IPv4 |
|---|---|---|---|---|
| Bastion | `ewb-bastion` | `ewb-a-public` | `10.10.1.10` | Required |
| Application A | `ewb-app-a` | `ewb-a-private` | `10.10.2.10` | Not permitted |
| Application B | `ewb-app-b` | `ewb-b-private` | `10.20.1.10` | Not permitted |

The bastion's public IPv4 address is assigned by AWS and recorded after
launch (`terraform output -raw bastion_public_ip`).

Private IP addresses are configured explicitly when creating the EC2
instances. If an address is unavailable, investigate the subnet
configuration before choosing another address. Update every dependent
security-group rule, SSH configuration entry, and test command if an address
is intentionally changed.

---

## 6. AWS Resource Naming Convention

Use consistent resource names throughout the project.

| Resource Type | Name |
|---|---|
| VPC A | `ewb-vpc-a` |
| VPC B | `ewb-vpc-b` |
| Public subnet A | `ewb-a-public` |
| Private subnet A | `ewb-a-private` |
| Private subnet B | `ewb-b-private` |
| Internet Gateway | `ewb-igw-a` |
| Public route table | `ewb-rt-a-public` |
| Private route table A | `ewb-rt-a-private` |
| Private route table B | `ewb-rt-b-private` |
| Bastion security group | `ewb-sg-bastion` |
| App-A security group | `ewb-sg-app-a` |
| App-B security group | `ewb-sg-app-b` |
| Bastion EC2 | `ewb-bastion` |
| App-A EC2 | `ewb-app-a` |
| App-B EC2 | `ewb-app-b` |
| VPC peering connection | `ewb-a-b-peer` |
| EC2 key pair | `ewb-lab` |

### Resource Tags

Apply these tags to supported resources:

| Tag | Value |
|---|---|
| Project | `EWB-VPC-Peering` |
| Student | `YOUR_NAME` |
| ManagedBy | `Terraform` |
| Environment | `Lab` |

Replace `YOUR_NAME` with the student's name.

If resources are created manually through the AWS Console, use the same
project and student tags. Omit `ManagedBy = Terraform` for resources that
are not managed by Terraform.

---

## 7. Repository Structure

OpenCode organizes the project using the following structure.

```
aws-vpc-peering/
│
├── README.md
│
├── .gitignore
│
├── .terraform.lock.hcl       # generated by terraform init (commit it)
│
├── versions.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── main.tf                   # AMI lookup, key pair, VPC peering connection
├── networking.tf             # VPCs, subnets, IGW, route tables, routes
├── security.tf               # security groups
├── compute.tf                # EC2 instances
├── outputs.tf
│
├── terraform.tfvars.example
│
├── scripts/
│   ├── configure-ssh.sh
│   ├── verify-connectivity.sh
│   └── validate-aws-resources.sh
│
├── docs/
│   ├── architecture.md
│   ├── network-design.md
│   ├── security-model.md
│   ├── testing.md
│   ├── troubleshooting.md
│   └── cleanup.md
│
└── evidence/
    ├── .gitkeep
    └── README.md
```

### Repository Rules

1. Do not commit AWS credentials.
2. Do not commit private SSH keys.
3. Do not commit Terraform state files.
4. Do not commit generated plans containing sensitive data.
5. Do not store real credentials in `terraform.tfvars`.
6. Do not automatically deploy resources when opening the project.
7. Do not automatically destroy resources without explicit authorization.
8. Keep generated evidence separate from source code.
9. Keep the manual AWS Console procedure documented even if Terraform is used.
10. Clearly identify which resources are managed by Terraform and which are
    managed manually.

The Terraform implementation is an optional automation layer over the
required lab architecture. It must not silently change the project design.

---

## 8. Infrastructure Implementation

The project can be implemented using either the AWS Management Console or
Terraform.

### Option A: AWS Management Console

Follow this order:

1. Create VPC A.
2. Create the public and private subnets in VPC A.
3. Create and attach the Internet Gateway to VPC A.
4. Create the public route table and associate the public subnet.
5. Create the private route table and associate the private subnet.
6. Create VPC B.
7. Create the private subnet in VPC B.
8. Create the private route table in VPC B.
9. Create the three security groups.
10. Create the EC2 key pair.
11. Launch the bastion.
12. Launch App-A.
13. Launch App-B.
14. Verify the instance addresses and security-group associations.
15. Establish SSH connectivity to the bastion and App-A.
16. Capture the baseline failed ping.
17. Create and accept the VPC peering connection.
18. Configure routes on both sides and in the bastion subnet.
19. Test connectivity in both directions.
20. Test SSH access to App-B through the bastion.
21. Perform the controlled ICMP failure and recovery test.
22. Capture the required evidence.
23. Clean up the AWS resources.

### Option B: Terraform

The implementation included here provides:

* AWS provider configuration (region from a variable, standard credential chain).
* Input variables with validation.
* VPCs and subnets.
* Internet Gateway.
* Route tables and explicit subnet associations.
* Security groups.
* EC2 instances.
* VPC peering connection.
* Route resources.
* Outputs for resource IDs and IP addresses.
* Validation scripts.
* Safe deployment and cleanup instructions.

The implementation is idempotent: repeated Terraform plans propose no
changes once the infrastructure reaches the desired state. Explicit resource
dependencies are used where necessary. No provisioners copy private keys to
EC2 instances, and no credentials are embedded in source files.

#### Deployment Modes

Both modes are implemented via the `deployment_mode` variable:

* **Mode 1 - Staged Lab** (`deployment_mode = "staged"`): creates VPCs,
  subnets, IGW, route tables, security groups and instances, but **no
  peering connection and no peering routes**. This lets the required
  pre-peering failure be demonstrated honestly. The staged lab cannot
  accidentally establish peering or peer routes before the baseline test
  (requirement: documented mode switch, explicit plan + apply).
* **Mode 2 - Complete Infrastructure** (`deployment_mode = "complete"`):
  additionally creates the peering connection and all three peering routes.
  Switching modes is an explicit `terraform apply` after plan review; the
  baseline failure evidence must be captured *before* switching.

Quick start for both modes is in section 26.

---

## 9. Route Table Configuration

Three route tables are configured.

### Route Table A: Public Subnet

Name: `ewb-rt-a-public`. Associated subnet: `ewb-a-public`.

| Destination | Target | Purpose |
|---|---|---|
| `10.10.0.0/16` | `local` | VPC A internal traffic |
| `0.0.0.0/0` | Internet Gateway | Bastion internet connectivity |
| `10.20.0.0/16` | VPC peering connection | Bastion access to VPC B |

### Route Table B: Private Subnet A

Name: `ewb-rt-a-private`. Associated subnet: `ewb-a-private`.

| Destination | Target | Purpose |
|---|---|---|
| `10.10.0.0/16` | `local` | VPC A internal traffic |
| `10.20.0.0/16` | VPC peering connection | App-A to VPC B |

### Route Table C: Private Subnet B

Name: `ewb-rt-b-private`. Associated subnet: `ewb-b-private`.

| Destination | Target | Purpose |
|---|---|---|
| `10.20.0.0/16` | `local` | VPC B internal traffic |
| `10.10.0.0/16` | VPC peering connection | Return traffic to VPC A |

Replace the placeholder peering target with the actual peering connection ID
(in rows 3 of Route Table A, row 2 of Route Table B, row 2 of Route Table C).

### Routing Requirements

* Preserve AWS-created local routes.
* Use the correct peering connection as the route target.
* Explicitly associate every intended subnet with its route table.
* Do not associate VPC B's private subnet with VPC A's route table.
* Do not route VPC B traffic through the Internet Gateway.
* Do not add a NAT gateway.
* Do not add unnecessary default routes to the private subnets.

A peering connection alone does not establish end-to-end connectivity. Both
sides need the appropriate routes, and the security controls must permit the
traffic.

---

## 10. Security Group Configuration

Security groups are stateful virtual firewalls associated with the EC2
network interfaces.

Use the following inbound rules.

### Bastion Security Group

Name: `ewb-sg-bastion`. VPC: `ewb-vpc-a`.

| Protocol | Port | Source | Purpose |
|---|---|---|---|
| TCP | 22 | Administrator's public IPv4 `/32` | SSH to bastion |

Do not allow SSH from `0.0.0.0/0`. The administrator's current public IP
address must be used. If it changes, update the rule (`var.admin_cidr`).

### App-A Security Group

Name: `ewb-sg-app-a`. VPC: `ewb-vpc-a`.

| Protocol | Port or Type | Source | Purpose |
|---|---|---|---|
| TCP | 22 | `10.10.1.10/32` | SSH from bastion |
| ICMPv4 | Echo request (type 8) | `10.20.1.10/32` | Ping from App-B |

### App-B Security Group

Name: `ewb-sg-app-b`. VPC: `ewb-vpc-b`.

| Protocol | Port or Type | Source | Purpose |
|---|---|---|---|
| TCP | 22 | `10.10.1.10/32` | SSH from bastion |
| ICMPv4 | Echo request (type 8) | `10.10.2.10/32` | Ping from App-A |

For ICMP, Echo request is configured as type 8, code 0 where the interface
requests the specific ICMP type and code.

Keep the default outbound allow-all rules for this educational lab. Use the
default allow-all network ACLs unless the lab is explicitly extended to
cover stateless ACL design.

### Security Requirements

* Never expose SSH to the entire internet.
* Do not use `0.0.0.0/0` as the source for application-server SSH rules.
* Use the bastion's private IP as the source for private-instance SSH access.
* Use the other application's private IP as the source for ICMP testing.
* Keep application servers without public IP addresses.
* Do not use broad VPC CIDRs as security-group sources when a narrower
  host-specific rule is required by this lab.
* Do not introduce additional inbound rules without documenting their purpose.

---

## 11. EC2 Instance Configuration

### Operating System

Amazon Linux 2023.

### Instance Type

An instructor-approved small x86 instance type, such as `t3.micro`.
Confirm regional availability, account eligibility, and current pricing
before launch.

### Key Pair

Use `ewb-lab`. Store the private key locally.

On macOS or Linux:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
chmod 400 ~/.ssh/ewb-lab.pem
```

The file must already exist at the specified location. Do not upload the
private key to AWS, GitHub, or the bastion.

### Instance Summary

| Instance | VPC | Subnet | Private IPv4 | Public IPv4 |
|---|---|---|---|---|
| `ewb-bastion` | `ewb-vpc-a` | `ewb-a-public` | `10.10.1.10` | Yes |
| `ewb-app-a` | `ewb-vpc-a` | `ewb-a-private` | `10.10.2.10` | No |
| `ewb-app-b` | `ewb-vpc-b` | `ewb-b-private` | `10.20.1.10` | No |

### EC2 Requirements

* Use the same SSH key pair for all three instances.
* Use `ec2-user` as the default SSH username for Amazon Linux 2023.
* Configure the intended private IPv4 addresses.
* Disable public IPv4 assignment for App-A and App-B.
* Enable public IPv4 assignment for the bastion.
* Confirm that all instances pass their EC2 status checks.
* Avoid installing unnecessary packages.
* Do not require internet access from either private application server for
  the base lab.

---

## 12. SSH Configuration

On macOS, Linux, or WSL, configure SSH using the local OpenSSH client.

Create or edit `~/.ssh/config` (or let `scripts/configure-ssh.sh` do it
safely - see section 26):

```
Host ewb-bastion
    HostName BASTION_PUBLIC_IP
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
```

Replace `BASTION_PUBLIC_IP` with the actual public IPv4 address assigned to
the bastion.

Set suitable permissions:

```bash
chmod 600 ~/.ssh/config
chmod 400 ~/.ssh/ewb-lab.pem
```

Test the bastion: `ssh ewb-bastion`
Test App-A: `ssh ewb-app-a`
Test App-B: `ssh ewb-app-b`

SSH ProxyJump creates a separate SSH connection from the bastion to the
destination host. It does not require copying the private key onto the
bastion.

The bastion must have a route to VPC B, and App-B must allow SSH from the
bastion's private IP.

Verify the remote host after connecting:

```bash
hostname
hostname -I
```

---

## 13. Connectivity Testing

The project must demonstrate successful and unsuccessful connectivity under
controlled conditions.

**Expected results in this section are acceptance criteria, not evidence
that the project has already been executed.**

### Test 1: Baseline Failure Before Peering

Connect to App-A: `ssh ewb-app-a`

Run: `ping -c 4 10.20.1.10`

Expected result: no replies from App-B before peering routes are
configured. Capture the actual terminal output.

If the test unexpectedly succeeds, investigate existing peering connections,
route tables, and security-group rules.

### Test 2: Forward Connectivity

After establishing peering and configuring the routes, connect to App-A:
`ssh ewb-app-a`

Run: `ping -c 4 10.20.1.10`

Expected result: `4 packets transmitted, 4 received, 0% packet loss`

### Test 3: Reverse Connectivity

Connect to App-B: `ssh ewb-app-b`

Run: `ping -c 4 10.10.2.10`

Expected result: `4 packets transmitted, 4 received, 0% packet loss`

### Test 4: Private SSH

From the local laptop: `ssh ewb-app-b`

Expected result:

* SSH connects through the bastion.
* The shell is running on App-B.
* The remote private IP is `10.20.1.10`.

### Test 5: Public IP Isolation

Inspect the EC2 instance details.

Expected result:

* `ewb-app-a`: no public IPv4 address
* `ewb-app-b`: no public IPv4 address

### Test 6: Controlled ICMP Failure

In `ewb-sg-app-b`, temporarily remove the inbound ICMP Echo request rule
from `10.10.2.10/32`.

Repeat the ping from App-A: `ping -c 4 10.20.1.10`

Expected result: no ICMP replies from App-B.

Restore the exact ICMP rule. Repeat the ping. Expected result: connectivity
resumes.

Keep the SSH rule in place throughout this test.

### Testing Principles

* Capture real terminal output.
* Never fabricate successful ping results.
* Label screenshots with the host, command, and result.
* Record the actual AWS resource IDs.
* Keep the test commands reproducible.
* Investigate unexpected results before continuing.
* Restore any temporarily modified security rule.

---

## 14. Validation Scripts

OpenCode should implement small, readable validation scripts.

### Script 1: SSH Configuration - `scripts/configure-ssh.sh`

Responsibilities:

* Check that the SSH key exists.
* Verify that the SSH configuration contains the required host entries.
* Validate file permissions where possible.
* Avoid printing private-key contents.
* Never overwrite an existing SSH configuration without confirmation.
* Replace only explicitly provided placeholders.
* Never invent a bastion public IP.

The script supports a safe preview mode (`--dry-run`).

### Script 2: Connectivity Verification - `scripts/verify-connectivity.sh`

Responsibilities:

* Provide the expected ping commands for App-A and App-B.
* Support testing through SSH aliases.
* Display clear success and failure messages.
* Distinguish an expected pre-peering failure from an unexpected
  post-peering failure (`--expect fail|success`).
* Return a non-zero exit status when a required post-peering test fails.
* Never claim connectivity has been tested unless a real command was
  executed and its result checked.

The script must not automatically remove security rules (it never modifies
AWS state at all).

### Script 3: AWS Resource Validation - `scripts/validate-aws-resources.sh`

Responsibilities:

* Check that the AWS CLI is installed.
* Check the caller identity using AWS STS.
* Identify the configured AWS Region.
* Verify the existence of the two VPCs.
* Verify the expected subnet CIDRs.
* Verify the peering connection state.
* Verify the intended route tables and routes.
* Verify that App-A and App-B do not have public IPv4 addresses.
* Report missing or inconsistent resources.
* Avoid modifying AWS resources (read-only `describe-*` commands only).

The validation script must not assume that resource IDs are constant across
deployments (it locates everything by the documented `Name` tags).

---

## 15. Terraform Requirements

### Provider Configuration

* Use the official AWS Terraform provider.
* The AWS region is configurable through a variable (default `ap-south-1`).
* No AWS credentials are embedded in Terraform files; the standard AWS
  credential chain, AWS CLI profiles, environment configuration, or an
  approved role-based authentication method is used.

### Version Constraints

* `terraform >= 1.5.0`, `aws provider >= 5.0 < 6.0` (`versions.tf`).
* Commit `.terraform.lock.hcl` after provider initialization and validation.
* Do not commit the `.terraform/` working directory.

### Variables

Supported variables (all validated in `variables.tf`): AWS region, student
name, project name, environment tag, instance type, optional AMI ID
(region-aware AMI lookup by default), administrator public IPv4 `/32`
CIDR, EC2 key pair name, key pair creation toggle + public key material,
deployment mode, and the CIDR/private-IP plan values.

### Outputs

`outputs.tf` provides: VPC A ID, VPC B ID, public subnet ID, private subnet
A ID, private subnet B ID, Internet Gateway ID, public route table ID,
private route table A ID, private route table B ID, peering connection ID
(null in staged mode), bastion instance ID, App-A instance ID, App-B
instance ID, bastion public IPv4, bastion private IPv4, App-A private IPv4,
App-B private IPv4. No outputs expose credentials or private-key material.

### Terraform State

State is sensitive infrastructure metadata. Do not commit `terraform.tfstate`,
`terraform.tfstate.backup`, `*.tfstate`, `*.tfstate.*` (enforced by
`.gitignore`). No remote state backend requiring paid infrastructure is
configured; local state is acceptable for this educational lab if kept
private and backed up appropriately.

### Safe Deployment

Understand the difference before running anything:

```
terraform init        # download providers, create .terraform.lock.hcl
terraform fmt -check  # formatting check
terraform validate    # syntax/consistency check (no AWS access needed)
terraform plan        # REVIEW the planned changes carefully
terraform apply       # EXPLICIT user action only, after plan review
```

Before deployment, inspect the plan and confirm the account, region,
estimated resources, and potential charges. Never run `terraform apply`
automatically.

### Safe Cleanup

```
terraform plan -destroy   # REVIEW
terraform destroy         # EXPLICIT user action only
```

Terraform can destroy every resource managed by the selected state. If a
resource was created manually rather than through Terraform, Terraform
cannot be assumed to manage or delete it (see `docs/cleanup.md`).

---

## 16. Cost Management

This project is intended for educational use.

AWS charges vary by region, instance type, usage, account eligibility, and
current pricing. Potentially chargeable resources include EC2 instances,
EBS volumes, public IPv4 addresses, and data transfer.

A NAT gateway is **not** required and is **not** created.

### Cost-Safety Requirements

1. Review current AWS pricing before deployment.
2. Check Free Tier or promotional-credit eligibility.
3. Use an approved small EC2 instance type.
4. Avoid unnecessary storage (8 GiB gp3 root volumes, delete-on-termination).
5. Avoid creating Elastic IP addresses unless required (default flow: none).
6. Do not create NAT gateways (not created anywhere in this repository).
7. Do not create load balancers.
8. Do not create unnecessary monitoring or logging services.
9. Keep resources only for the duration of the lab.
10. Verify that resources have been removed after cleanup.
11. Check AWS Billing after cleanup because billing data may not update
    immediately.

Do not promise that the project is free. Do not claim that an account
qualifies for free usage without verifying the account's eligibility.

---

## 17. Troubleshooting

See `docs/troubleshooting.md` for the full text. Summary (problem -> check):
bastion SSH times out (running state, current public IP, public route table,
IGW route, admin /32 SG rule, NACLs); App-A SSH fails (state/private IP/SG,
key, user, SSH config); App-B SSH fails (peering Active, public-subnet peer
route, return route, SSH source `10.10.1.10/32`, key/user); ping fails after
peering (peering Active, routes on BOTH sides, ICMP rules both directions,
pinned IPs, NACLs, instance state); peering cannot be created (overlapping
primary or secondary CIDRs); permission denied (key/username/config); private
instances cannot download packages (intentional: no NAT egress - not a
peering problem); Terraform shows unexpected changes (profile/region/state,
manual console drift, stale region-pinned AMI). Review the plan before
applying anything.

---

## 18. Security Considerations

This is an educational networking lab, not a complete production
architecture. Required controls:

* Restrict SSH access to the bastion (admin `/32` only).
* Keep private application servers without public IPv4 addresses.
* Scope private-instance SSH access to the bastion's private IP.
* Scope ICMP rules to the peer application host.
* Keep private keys on the administrator's machine.
* Do not store AWS access keys in source code.
* Do not publish Terraform state.
* Do not expose private keys or credentials in screenshots.
* Remove lab resources after completion.

For a production environment, consider (optional extensions - do not
represent them as completed features unless actually implemented): AWS
Systems Manager Session Manager; IAM roles with least-privilege policies;
centralized logging and audit trails; more restrictive outbound
security-group rules; explicitly designed network ACLs; automated policy
and configuration validation; a managed Terraform state backend with
encryption and access controls; a documented patching and
vulnerability-management process.

---

## 19. Deliverables

The final submission must contain evidence of actual implementation.

### Required Report

Filename: `YourName_EWB_VPC_Peering.pdf` (replace `YourName` with the
student's name). The report must include:

1. Cover page.
2. Project objective.
3. Architecture diagram.
4. IP addressing plan.
5. AWS resource inventory.
6. VPC and subnet configuration.
7. Route-table configuration and subnet associations.
8. Active peering connection.
9. Security-group rules.
10. Baseline ping failure before peering.
11. Successful App-A to App-B ping.
12. Successful App-B to App-A ping.
13. SSH access to App-B through the bastion.
14. Proof that App-A and App-B have no public IPv4 addresses.
15. Controlled ICMP failure.
16. Successful recovery after restoring the ICMP rule.
17. Cleanup evidence.
18. Lessons learned.

### Required Evidence

Save screenshots in `evidence/` (see `evidence/README.md` for the
recommended filenames `01-vpc-a.png` ... `14-cleanup.png`).

Rules:

* Use only screenshots that represent actual results.
* Do not generate fake screenshots or synthetic terminal output.
* Do not include private keys, credentials, account secrets, or unnecessary
  personal information in the report.

---

## 20. Evaluation Criteria

| Assessment Area | Marks |
|---|---|
| Architecture, CIDRs, and resource inventory | 15 |
| Subnets, Internet Gateway, and correct route associations | 20 |
| Peering and forward/return routes | 20 |
| Security rules and private SSH access | 20 |
| Positive and negative test evidence with explanations | 15 |
| Report clarity, viva, and cleanup evidence | 10 |
| **Total** | **100** |

### Acceptance Criteria

The project is considered complete only when:

* Both VPCs exist with non-overlapping CIDRs.
* All three subnets exist.
* All three EC2 instances exist and are configured correctly.
* Only the bastion has a public IPv4 address.
* The peering connection is Active.
* Both private route tables contain the correct peer routes.
* The public route table contains the required route to VPC B.
* The required security-group rules are present.
* Baseline failure evidence is recorded.
* Bidirectional ping connectivity is demonstrated.
* Private SSH access to App-B works through the bastion.
* The controlled failure and recovery are demonstrated.
* The report contains actual execution evidence.
* Resources are cleaned up after evidence collection.

---

## 21. Viva Questions and Answers

**Q1. What is an Amazon VPC?**
An Amazon Virtual Private Cloud is a logically isolated virtual network in
AWS in which users configure IP address ranges, subnets, routes, and network
security controls.

**Q2. What is VPC peering?**
VPC peering establishes private network connectivity between two VPCs using
their private IP address ranges.

**Q3. Why must the VPC CIDRs not overlap?**
Overlapping address ranges create ambiguity in routing between the networks.
Standard VPC peering requires non-overlapping IPv4 CIDRs.

**Q4. Why are route tables necessary?**
Route tables determine where packets are sent based on their destination IP
addresses.

**Q5. Why are routes needed on both sides?**
Traffic needs a forward route to reach the destination and a return route to
deliver the response. A route on only one side is insufficient for normal
bidirectional communication.

**Q6. Why does the bastion have a public IP?**
The administrator needs an internet-reachable entry point for SSH access.
The bastion provides that entry point while the application servers remain
private.

**Q7. Why do App-A and App-B have no public IP addresses?**
They are private workloads that should not accept direct inbound connections
from the public internet.

**Q8. Why does App-B allow SSH from `10.10.1.10/32`?**
The bastion initiates the SSH connection to App-B using its private IP as
the source address.

**Q9. Does VPC peering automatically provide internet access?**
No. VPC peering provides private connectivity between the peered networks.
It does not automatically give one VPC access to another VPC's Internet
Gateway.

**Q10. What is the purpose of the controlled ICMP failure test?**
It demonstrates that a security-group rule directly affects traffic
authorization and that restoring the rule restores connectivity when the
remaining configuration is correct.

**Q11. Why is the peering connection's Active status insufficient proof?**
An Active connection confirms that the peering connection is established.
Routing, security groups, network ACLs, and instance configuration must also
permit the traffic.

**Q12. Is VPC peering transitive?**
No. If VPC A peers with VPC B and VPC A peers with VPC C, VPC B does not
automatically obtain connectivity to VPC C through VPC A.

**Q13. What is the difference between a public subnet and a private subnet?**
A public subnet generally has a route to an Internet Gateway. A private
subnet does not have that direct internet route. An instance also needs
appropriate addressing and security configuration for internet
communication.

**Q14. Why is a NAT gateway unnecessary for this lab?**
The required workloads communicate privately, and the project does not
require internet egress from the private application servers.

**Q15. What is SSH ProxyJump?**
SSH ProxyJump allows the SSH client to connect to a destination host through
an intermediate host, such as a bastion, without copying the private key to
the intermediate host.

---

## 22. Cleanup Procedure

Cleanup is mandatory after all evidence has been collected. Full details:
`docs/cleanup.md`.

### If Terraform manages the infrastructure

Review the selected Terraform workspace and state before destroying anything:

```bash
terraform plan -destroy
```

Inspect the plan carefully. If the plan contains only the intended lab
resources, the authorized operator can run:

```bash
terraform destroy
```

Review and confirm the proposed destruction when prompted. Do not use this
procedure if the Terraform state manages unrelated infrastructure. Do not
assume that manually created resources will be destroyed by Terraform.

### If resources were created manually

Use the AWS Console to remove only the resources created for this project.
Recommended order:

1. Terminate `ewb-bastion`, `ewb-app-a`, `ewb-app-b`.
2. Verify that lab EBS volumes are deleted.
3. Remove any lab snapshots that are no longer needed.
4. Release any Elastic IP allocated for the lab.
5. Delete the VPC peering connection.
6. Remove the peer routes.
7. Delete the security groups after their associated network interfaces are
   removed.
8. Delete the lab subnets.
9. Delete the custom route tables.
10. Detach the Internet Gateway.
11. Delete the Internet Gateway.
12. Delete VPC A and VPC B.
13. Delete the unused lab key pair if appropriate.
14. Verify that no project resources remain.

Check the AWS Billing console after cleanup. Usage and billing information
may not update immediately.

Never delete unrelated AWS resources.

---

## 23. References

Use the official AWS documentation for current technical details.

* Amazon VPC Peering
* Create a VPC Peering Connection
* Update Route Tables for VPC Peering
* Security Groups for Your VPC
* Amazon EC2 Key Pairs
* Amazon Linux 2023
* Terraform AWS Provider
* Terraform CLI Documentation

Check current AWS pricing before creating resources.

---

## 24. Final Checklist

### Network

* [ ] VPC A created.
* [ ] VPC B created.
* [ ] CIDR ranges do not overlap.
* [ ] Public subnet A created.
* [ ] Private subnet A created.
* [ ] Private subnet B created.
* [ ] Internet Gateway attached to VPC A.
* [ ] Correct route tables created.
* [ ] Correct subnet associations configured.

### Security

* [ ] Bastion SSH restricted to the administrator's public IPv4 `/32`.
* [ ] App-A SSH restricted to the bastion.
* [ ] App-B SSH restricted to the bastion.
* [ ] App-A ICMP rule configured.
* [ ] App-B ICMP rule configured.
* [ ] Application servers have no public IPv4 addresses.
* [ ] Private SSH key remains on the administrator's machine.

### Connectivity

* [ ] Baseline ping failure recorded.
* [ ] VPC peering connection Active.
* [ ] App-A forward route configured.
* [ ] App-B return route configured.
* [ ] Bastion route to VPC B configured.
* [ ] Forward ping successful.
* [ ] Reverse ping successful.
* [ ] SSH to App-B through the bastion successful.
* [ ] Controlled ICMP failure demonstrated.
* [ ] Connectivity restored after rule restoration.

### Submission

* [ ] Architecture diagram included.
* [ ] Actual AWS resource IDs recorded.
* [ ] Route tables documented.
* [ ] Security-group rules documented.
* [ ] Actual test output captured.
* [ ] Report PDF generated.
* [ ] No credentials or private keys included.

### Cleanup

* [ ] Lab EC2 instances terminated.
* [ ] Unused lab storage removed.
* [ ] Peering connection removed.
* [ ] Lab security groups and routes removed.
* [ ] Lab subnets and route tables removed.
* [ ] Internet Gateway detached and deleted.
* [ ] Lab VPCs deleted.
* [ ] AWS Billing checked for remaining resources.

---

## 25. Instructions for OpenCode

Use this README as the source of truth for the project. When implementing
the repository:

1. Inspect the existing repository before modifying any files.
2. Preserve existing working code unless a change is necessary.
3. Implement the infrastructure according to the documented architecture.
4. Preserve the specified VPC CIDRs, subnet CIDRs, private IP addresses,
   resource names, route tables, and security-group rules.
5. Separate networking, security, compute, variables, outputs, and scripts
   into understandable files.
6. If Terraform is used, implement valid and maintainable Terraform
   configuration.
7. Do not embed AWS credentials or private keys in any source file.
8. Do not create resources automatically when the project is opened.
9. Do not execute `terraform apply`, `terraform destroy`, or destructive AWS
   CLI commands without explicit user authorization.
10. Provide safe commands for formatting, validation, planning, deployment,
    testing, and cleanup.
11. Implement read-only validation scripts where practical.
12. Ensure that the staged lab can demonstrate the required baseline failure
    before peering and peer routes are configured.
13. Do not claim that AWS resources exist or connectivity works without
    verifying actual AWS state or test output.
14. Do not fabricate screenshots, resource IDs, ping results, or test reports.
15. Clearly distinguish implemented features from proposed improvements.
16. Document any deviation from this README before implementing it.
17. Ensure all scripts are readable, documented, and appropriate for macOS
    or Linux where applicable.
18. Explain every required AWS Console step that is not automated.
19. Include troubleshooting instructions for common routing, SSH, and
    security-group problems.
20. Before deployment, summarize the resources to be created, the likely
    cost categories, the required permissions, and any unresolved
    configuration values.

### Definition of Done

The project is complete when the repository contains the documented
architecture, valid infrastructure configuration for the chosen deployment
mode, appropriate security controls, reproducible validation commands,
troubleshooting documentation, and a clear cleanup procedure.

The live AWS deployment is complete only after the required resources have
been created, the actual connectivity tests have passed, the controlled
failure and recovery have been demonstrated, and the results have been
recorded.

Do not mark live infrastructure tests as passed merely because the Terraform
configuration validates.

---

## 26. Implemented Repository: Status and Quick Start

This section documents what is actually implemented (per instruction 20 /
15 of section 25) and how to run it.

### What is implemented

| Area | Status |
|---|---|
| Terraform (staged **and** complete modes) | Implemented (`*.tf`) |
| All three validation/helper scripts | Implemented (`scripts/*.sh`) |
| Architecture / design / security / testing / troubleshooting / cleanup docs | Implemented (`docs/`) |
| Evidence convention | Implemented (`evidence/README.md`) |
| Live AWS deployment | **NOT performed** - no AWS resources exist |
| Connectivity tests / screenshots | **NOT performed** - do not claim them anywhere |
| `.terraform.lock.hcl` | Not present yet - `terraform init` generates it |

**Neither terraform nor the AWS CLI was installed on this machine when the
repository was created; nothing was deployed, and no AWS API calls were
made.**

### Quick start (Mode 1 staged, then Mode 2 complete)

```bash
cd aws-vpc-peering

# 0) Prerequisites once: Terraform >= 1.5, AWS CLI v2, AWS credentials.
#    Generate the local key pair - the private part never leaves the machine:
ssh-keygen -t ed25519 -f ~/.ssh/ewb-lab.pem -C "ewb-lab"
chmod 700 ~/.ssh && chmod 400 ~/.ssh/ewb-lab.pem

# 1) Configure inputs (set admin_cidr to your public IP /32 and student_name):
cp terraform.tfvars.example terraform.tfvars
#    edit terraform.tfvars; find your IP: curl -s https://checkip.amazonaws.com

# 2) Initialize and validate (no resources are created by these steps):
terraform init                    # creates .terraform.lock.hcl - commit it
terraform fmt -check
terraform validate
terraform plan                    # REVIEW: account, region, costs, resources

# 3) Deploy Stage 1 - explicit, after your own review of the plan:
terraform apply
#    (key pair: either set create_key_pair=true + public_key beforehand, or
#     create the 'ewb-lab' key pair once in the console and keep
#     create_key_pair=false)

# 4) Configure local SSH (never invents the bastion IP):
terraform output -raw bastion_public_ip
./scripts/configure-ssh.sh --bastion-ip <BASTION_PUBLIC_IP> --dry-run   # preview
./scripts/configure-ssh.sh --bastion-ip <BASTION_PUBLIC_IP>            # apply

# 5) Baseline test - the REQUIRED expected failure (staged mode):
./scripts/verify-connectivity.sh a2b --expect-fail     # capture as evidence 08
./scripts/validate-aws-resources.sh --mode staged

# 6) Deploy Stage 2 - peering + all three peer routes (explicit apply):
terraform plan -var='deployment_mode=complete'        # review first
terraform apply -var='deployment_mode=complete'

# 7) Positive tests:
./scripts/validate-aws-resources.sh --mode complete
./scripts/verify-connectivity.sh a2b                  # evidence 09
./scripts/verify-connectivity.sh b2a                  # evidence 10
ssh ewb-app-b 'hostname -I'                           # evidence 11 (10.20.1.10)

# 8) Controlled ICMP failure/recovery - manual, authorized step (docs/testing.md):
#    remove ICMP rule on ewb-sg-app-b -> rerun a2b (expect FAIL, exit 2)
#    restore the exact rule        -> rerun a2b (expect PASS, exit 0)

# 9) Cleanup (explicit, after reviewing the plan):
terraform plan -destroy
terraform destroy
```

### Before you deploy - unresolved values and expectations

* **Unresolved inputs**: your public IPv4 (`admin_cidr`), student name, and
  the bastion public IP (after Stage 1).
* **Resources created by Stage 1 (staged)**: 2 VPCs, 3 subnets, 1 IGW,
  3 route tables + 3 associations + 1 internet route, 3 security groups,
  3 EC2 instances (t3.micro, 8 GiB gp3 each), optional key pair.
  Stage 2 adds: 1 peering connection + 3 `aws_route` entries. Nothing else.
* **Cost categories**: EC2 instance hours, EBS storage, public IPv4
  address hours, minor data transfer. No NAT gateway, no load balancer,
  no Elastic IP by default. Verify current pricing and Free Tier
  eligibility yourself - the lab is not promised to be free.
* **IAM permissions needed** (deployment): EC2 full management for the lab
  instances/key pairs, VPC full management for the lab networks; the
  validation script needs only `sts:GetCallerIdentity` + `ec2:Describe*`.

### Manual console procedure

If you deploy via the console instead, follow section 8 Option A step by
step using the same names, CIDRs, rules and tags documented above - every
step not automated by Terraform is enumerated there.







