#!/usr/bin/env bash
#
# verify-connectivity.sh
# Runs the required ICMP tests of README section 13 through the SSH aliases
# created by scripts/configure-ssh.sh, prints the real terminal output, and
# states clearly whether the observed result matches the expectation.
#
# Guarantees (README section 14):
#   * Never claims connectivity was tested unless a real ssh+ping command
#     was executed and its result was actually checked.
#   * Never modifies AWS resources; it never removes security rules.
#   * Returns a non-zero exit status when a required post-peering test fails.
#
# Usage:
#   ./scripts/verify-connectivity.sh <a2b|b2a> [options]
#
# Directions:
#   a2b   ping App-B (10.20.1.10) from App-A      -> alias ewb-app-a
#   b2a   ping App-A (10.10.2.10) from App-B      -> alias ewb-app-b
#
# Options:
#   --expect <success|fail>  fail  = pre-peering baseline (expected failure);
#                            success (default) = post-peering test.
#   --count <N>              number of ping packets (default 4)
#   --timeout <SEC>          ssh connect timeout in seconds (default 10)
#   --help | -h              show this help
#
# Exit codes:
#   0   observed result matches the expectation (record as evidence)
#   1   could not run the test (environment / SSH configuration problem)
#   2   observed result does NOT match the expectation (test failure)

set -euo pipefail

DIRECTION=""
EXPECT="success"
COUNT=4
CONNECT_TIMEOUT=10

usage() { sed -n '2,34p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    a2b|b2a)    DIRECTION="$1"; shift ;;
    --expect)   EXPECT="${2:?--expect needs success|fail}"; shift 2 ;;
    --count)    COUNT="${2:?--count needs a number}"; shift 2 ;;
    --timeout)  CONNECT_TIMEOUT="${2:?--timeout needs seconds}"; shift 2 ;;
    --help|-h)  usage ;;
    *) echo "ERROR: unknown argument: $1 (see --help)" >&2; exit 1 ;;
  esac
done

if [[ -z "$DIRECTION" ]]; then
  echo "ERROR: direction is required: a2b or b2a (see --help)" >&2
  exit 1
fi
if [[ "$EXPECT" != "success" && "$EXPECT" != "fail" ]]; then
  echo "ERROR: --expect must be 'success' or 'fail'." >&2
  exit 1
fi
if ! echo "$COUNT" | grep -Eq '^[1-9][0-9]*$'; then
  echo "ERROR: --count must be a positive integer." >&2
  exit 1
fi

# Direction -> (ssh alias, ping target) mapping from the documented plan.
case "$DIRECTION" in
  a2b) ALIAS_NAME="ewb-app-a"; TARGET="${EWB_APP_B_REMOTE:-10.20.1.10}" ;;
  b2a) ALIAS_NAME="ewb-app-b"; TARGET="${EWB_APP_A_REMOTE:-10.10.2.10}" ;;
  *)   echo "ERROR: unreachable state." >&2; exit 1 ;;
esac

echo "Test: ping $TARGET from $ALIAS_NAME (expectation: $EXPECT)"
echo "Underlying command: ssh $ALIAS_NAME 'ping -c $COUNT \"$TARGET\"'"
echo

# The alias must be configured locally; ssh resolves it from ~/.ssh/config.
RESOLVED=$(ssh -G "$ALIAS_NAME" 2>/dev/null | awk '/^hostname /{print $2}' || true)
if [[ -z "$RESOLVED" || "$RESOLVED" == "$ALIAS_NAME" ]]; then
  echo "ERROR: SSH alias '$ALIAS_NAME' is not configured in your SSH config." >&2
  echo "       Run scripts/configure-ssh.sh --bastion-ip <PUBLIC_IP> first." >&2
  exit 1
fi

START=$(date +%s)
OUT=$(ssh -o BatchMode=yes \
           -o ConnectTimeout="${CONNECT_TIMEOUT}" \
           -o StrictHostKeyChecking=accept-new \
           "$ALIAS_NAME" "ping -c ${COUNT} ${TARGET}" 2>&1) && RC=0 || RC=$?
END=$(date +%s)
echo "----- actual remote output (exit code $RC) -----"
echo "$OUT"
echo "----- end of actual remote output -----"

if [[ "$RC" -eq 255 ]]; then
  echo
  echo "FAIL: could not even connect to $ALIAS_NAME (ssh exit 255)." >&2
  echo "      Check: bastion is running, bastion IP is current, security" >&2
  echo "      groups allow SSH (README section 17, Problems 1-3)." >&2
  exit 1
fi

RECEIVED=$(echo "$OUT" | grep -oE '[0-9]+ received' | tail -1 | awk '{print $1}')
RECEIVED="${RECEIVED:-0}"
MATCHED="unknown"
if [[ "$RC" -eq 0 && "$RECEIVED" -eq "$COUNT" ]]; then
  MATCHED="success"
elif [[ "$RECEIVED" -eq 0 ]]; then
  MATCHED="fail"
fi

echo
if [[ "$MATCHED" == "success" && "$EXPECT" == "success" ]]; then
  echo "PASS: $RECEIVED/$COUNT replies from $TARGET via $ALIAS_NAME."
  echo "      Capture this output as post-peering evidence."
  exit 0
elif [[ "$MATCHED" == "fail" && "$EXPECT" == "fail" ]]; then
  echo "PASS (expected failure): no replies from $TARGET via $ALIAS_NAME."
  echo "      Prior to peering this is the required baseline result"
  echo "      (README section 13, Test 1). Capture it as baseline evidence."
  exit 0
elif [[ "$MATCHED" == "fail" && "$EXPECT" == "success" ]]; then
  echo "FAIL: $RECEIVED/$COUNT replies from $TARGET via $ALIAS_NAME." >&2
  echo "      A post-peering test must succeed. Investigate in this order:" >&2
  echo "      1. peering Active  2. routes on BOTH sides  3. ICMP rules on" >&2
  echo "      both app security groups  4. instance state (README section 17)." >&2
  exit 2
elif [[ "$MATCHED" == "success" && "$EXPECT" == "fail" ]]; then
  echo "FAIL (unexpected success): ping worked although no peering was expected." >&2
  echo "      Ping should NOT succeed before peering. Investigate existing" >&2
  echo "      peering connections, route tables and security rules before" >&2
  echo "      recording this as baseline evidence (README section 13, Test 1)." >&2
  exit 2
else
  echo "FAIL: ambiguous result (ping exit $RC, parsed replies: $RECEIVED of $COUNT expected)." >&2
  echo "      Review the raw output above; do not record ambiguous evidence." >&2
  exit 2
fi
