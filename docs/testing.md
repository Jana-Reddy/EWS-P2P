# Testing Plan

Acceptance-mapped tests (README section 13). Everything below describes how
to produce evidence; none of these results exist until the commands are run
against real infrastructure. Never fabricate terminal output.

Run scripts from the repository root. Prerequisite:
`scripts/configure-ssh.sh --bastion-ip <BASTION_PUBLIC_IP>` must have been
applied successfully and both app SSH aliases must work first.

| # | Test | Command | Expected | Evidence file |
|---|---|---|---|---|
| 1 | Baseline failure before peering | `./scripts/verify-connectivity.sh a2b --expect-fail` | No replies (staged mode) | `evidence/08-baseline-ping-failure.png` |
| 2 | Forward connectivity | `./scripts/verify-connectivity.sh a2b` | 4/4 replies, 0% loss | `evidence/09-forward-ping-success.png` |
| 3 | Reverse connectivity | `./scripts/verify-connectivity.sh b2a` | 4/4 replies, 0% loss | `evidence/10-reverse-ping-success.png` |
| 4 | Private SSH to App-B | `ssh ewb-app-b` then `hostname -I` | shell on App-B, `10.20.1.10` | `evidence/11-private-ssh.png` |
| 5 | Public IP isolation | `./scripts/validate-aws-resources.sh --mode complete` | apps report no public IPv4 | `evidence/06-ec2-instances.png` |
| 6 | Controlled ICMP failure | remove + re-add rule manually (below) | fail then recover | `evidence/12-controlled-failure.png`, `13-connectivity-recovery.png` |

Exit codes of `verify-connectivity.sh`: `0` = result matched the
expectation; `1` = could not run (SSH/environment); `2` = result did NOT
match the expectation (post-peering failure or unexpected pre-peering
success). Constructed with `set -euo pipefail` the scripts abort on their
own errors, so a non-zero status means "investigate".

## Test ordering (README section 8, Mode 1 staged lab)

1. Deploy staged mode (no peering, no peer routes).
2. SSH to bastion and App-A must already work.
3. Run Test 1 - the **expected failure** - and capture output.
4. Switch to complete mode (explicit apply after plan review).
5. Run Tests 2-6 and capture outputs.

## Test 6: controlled ICMP failure and recovery (manual, authorized step)

`verify-connectivity.sh` never removes security rules. Perform this in the
AWS console (VPC -> Security Groups -> `ewb-sg-app-b` -> Inbound rules) or
with explicit permission using the AWS CLI:

```bash
# 1. Prove App-A -> App-B ping works (Test 2 above).
# 2. Remove the ICMP echo-request rule from ewb-sg-app-b (console: delete the
#    ICMP rule whose source is 10.10.2.10/32). Keep the SSH rule in place.
# 3. Re-run: ./scripts/verify-connectivity.sh a2b          # expect FAIL (exit 2)
# 4. Restore the exact rule: ICMP type 8 ("Echo Request"), source 10.10.2.10/32.
# 5. Re-run: ./scripts/verify-connectivity.sh a2b          # expect PASS (exit 0)
```

The reverse test (App-B -> App-A rule removal on `ewb-sg-app-a`) is an
optional symmetric demonstration.

## Resource validation

After each deployment stage:

```bash
./scripts/validate-aws-resources.sh --mode staged    # before peering exists
./scripts/validate-aws-resources.sh --mode complete  # after peering + routes
```

The script is read-only, prints the actual resource IDs it discovered, and
exits non-zero on any FAIL.

## Testing principles

* Capture real terminal output; label screenshots with host, command and result.
* Record actual AWS resource IDs (the validation script lists them).
* Investigate unexpected results before continuing (see `troubleshooting.md`).
* Restore anything temporarily modified (ICMP rule must be re-added).
* Never claim a test passed without having run it.
