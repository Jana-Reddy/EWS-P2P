# Evidence

Screenshots and captured terminal output for the final report go here
(README section 19). Suggested names (only keep **real** results - never
generate fake screenshots or synthetic terminal output):

| File | Content |
|---|---|
| `01-vpc-a.png` | VPC A overview, CIDR, resource IDs |
| `02-vpc-b.png` | VPC B overview |
| `03-subnets.png` | Subnets with NAT/public-IP assignment flags |
| `04-route-tables.png` | Route tables with subnet associations and routes |
| `05-security-groups.png` | Inbound rules of all three groups |
| `06-ec2-instances.png` | Instances with public/private addresses |
| `07-peering-active.png` | Peering connection state = Active |
| `08-baseline-ping-failure.png` | `verify-connectivity.sh a2b --expect-fail` |
| `09-forward-ping-success.png` | `verify-connectivity.sh a2b` after peering |
| `10-reverse-ping-success.png` | `verify-connectivity.sh b2a` after peering |
| `11-private-ssh.png` | `ssh ewb-app-b` + `hostname -I` |
| `12-controlled-failure.png` | Ping after ICMP rule removal |
| `13-connectivity-recovery.png` | Ping after the rule was restored |
| `14-cleanup.png` | Post-cleanup AWS state / billing check |

Rules:

* Label each screenshot with host, command and result.
* Include real AWS resource IDs; redact nothing locally sensitive, but never
  include private keys, credentials, account secrets or unnecessary personal
  information.
* Do not commit anything to `evidence/` that is not an actual lab result.
