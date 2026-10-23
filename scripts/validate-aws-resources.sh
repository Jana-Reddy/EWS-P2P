#!/usr/bin/env bash
#
# validate-aws-resources.sh
# READ-ONLY validation of the deployed EWB VPC Peering lab (README section 14).
# Uses only AWS CLI describe-* style commands; it never creates, changes or
# destroys AWS resources. It does not assume resource IDs are constant: every
# expected resource is located through its documented Name tag.
#
# Usage:
#   ./scripts/validate-aws-resources.sh [--region CODE] [--mode staged|complete]
#                                       [--profile NAME] [--help]
#
# Modes:
#   staged    - pre-peering state: peer routes must NOT exist; an active
#               peering connection is reported as unexpected.
#   complete  - final state: peering Active and all peering routes required.
#
# Exit codes:
#   0   everything evaluated as PASS (warnings allowed)
#   1   usage error / prerequisites missing / at least one FAIL
#
# Requirements: AWS CLI v2, credentials, and describe/lookup permissions
# (sts:GetCallerIdentity, ec2:Describe*).

set -uo pipefail

PASS=0
FAIL=0
WARN=0
MODE="complete"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
PROFILE=""

usage() { sed -n '2,24p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)  REGION="${2:?--region needs a code}"; shift 2 ;;
    --mode)    MODE="${2:?--mode needs staged|complete}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile needs a name}"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "ERROR: unknown argument: $1 (see --help)" >&2; exit 1 ;;
  esac
done

if [[ "$MODE" != "staged" && "$MODE" != "complete" ]]; then
  echo "ERROR: --mode must be 'staged' or 'complete'." >&2
  exit 1
fi

AWSC=(aws)
if [[ -n "$PROFILE" ]]; then
  AWSC+=(--profile "$PROFILE")
fi
awsread() { "${AWSC[@]}" --no-cli-pager --output text --region "$REGION" "$@"; }

# Report helpers write to stderr so that command substitution stays clean.
pass() { PASS=$((PASS+1)); printf '  [PASS] %s\n' "$1" >&2; }
fail() { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$1" >&2; }
warn() { WARN=$((WARN+1)); printf '  [WARN] %s\n' "$1" >&2; }
note() { printf '         %s\n' "$1" >&2; }

echo "======================================================"
echo " EWB VPC Peering lab - AWS resource validation"
echo " Mode: $MODE   Region: ${REGION:-<unresolved>}"
echo "======================================================"

# ------------------------------------------------------------------
# Prerequisites and identity
# ------------------------------------------------------------------
echo
echo "-- Environment --"
if ! command -v aws >/dev/null 2>&1; then
  fail "AWS CLI is not installed or not on PATH."
  exit 1
fi
CLI_VERSION=$(aws --version 2>/dev/null || echo unknown)
echo "AWS CLI: $CLI_VERSION"

if [[ -z "$REGION" ]]; then
  REGION=$("${AWSC[@]}" configure get region 2>/dev/null || true)
  if [[ -z "$REGION" ]]; then
    fail "No region configured. Set AWS_REGION, run 'aws configure' or pass --region."
    exit 1
  fi
  note "Region taken from the CLI profile: $REGION"
fi

STS_OUTPUT=$(awsread sts get-caller-identity --query '[Account, Arn]' 2>&1) || {
  fail "Could not authenticate to AWS STS. Check credentials, profile and region."
  echo "$STS_OUTPUT" >&2
  exit 1
}
echo "Caller identity: $STS_OUTPUT"
pass "AWS authentication works."

# ------------------------------------------------------------------
# VPCs
# ------------------------------------------------------------------
echo
echo "-- VPCs --"
vpc_id_for() { # $1=tag $2=expected cidr
  local id
  id=$(awsread ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$1" "Name=cidr-block,Values=$2" \
        --query 'Vpcs[0].VpcId' 2>/dev/null || true)
  [[ -n "$id" && "$id" != "None" ]] && echo "$id" || echo ""
}
VPC_A=$(vpc_id_for ewb-vpc-a 10.10.0.0/16)
VPC_B=$(vpc_id_for ewb-vpc-b 10.20.0.0/16)
if [[ -n "$VPC_A" ]]; then pass "VPC A ewb-vpc-a found (10.10.0.0/16): $VPC_A"; else fail "VPC A ewb-vpc-a with 10.10.0.0/16 not found."; fi
if [[ -n "$VPC_B" ]]; then pass "VPC B ewb-vpc-b found (10.20.0.0/16): $VPC_B"; else fail "VPC B ewb-vpc-b with 10.20.0.0/16 not found."; fi
if [[ -n "$VPC_A" && "$VPC_A" == "$VPC_B" ]]; then fail "VPC IDs unexpectedly match - inspect manually."; fi

# ------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------
echo
echo "-- Subnets --"
subnet_attr() { # $1=tag $2=jmespath
  awsread ec2 describe-subnets --filters "Name=tag:Name,Values=$1" \
      --query "Subnets[0].$2" 2>/dev/null || true
}
check_subnet() { # $1=tag $2=expected cidr $3=expected vpc $4="public"|"private"
  local id cidr vpc mapping
  id=$(subnet_attr "$1" "SubnetId")
  if [[ -z "$id" || "$id" == "None" ]]; then
    fail "Subnet $1 not found."
    return
  fi
  cidr=$(subnet_attr "$1" "CidrBlock")
  vpc=$(subnet_attr "$1" "VpcId")
  mapping="public"
  [[ "$4" == "private" ]] && mapping="private"
  if [[ "$cidr" == "$2" && "$vpc" == "$3" ]]; then
    pass "Subnet $1 OK ($cidr in $3): $id ($mapping)"
  else
    fail "Subnet $1 mismatch (cidr=$cidr vpc=$vpc; expected $2 in $3): $id"
  fi
}
check_subnet ewb-a-public   10.10.1.0/24 "$VPC_A" public
check_subnet ewb-a-private  10.10.2.0/24 "$VPC_A" private
check_subnet ewb-b-private  10.20.1.0/24 "$VPC_B" private
if [[ -n "$VPC_B" ]]; then
  IGW_A=$(awsread ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_A" --query 'InternetGateways[0].InternetGatewayId' 2>/dev/null || true)
  if [[ -n "$IGW_A" && "$IGW_A" != "None" ]]; then
    pass "Internet Gateway attached to VPC A: $IGW_A"
  else
    fail "No Internet Gateway attached to VPC A."
  fi
fi

# ------------------------------------------------------------------
# Route tables and routes
# ------------------------------------------------------------------
echo
echo "-- Route tables --"
rtb_attr() { # $1=tag $2=jmespath
  awsread ec2 describe-route-tables --filters "Name=tag:Name,Values=$1" \
      --query "RouteTables[0].$2" 2>/dev/null || true
}
check_rtb_assoc() { # $1=rtb tag $2=expected assoc subnet
  local id assoc
  id=$(rtb_attr "$1" "RouteTableId")
  if [[ -z "$id" || "$id" == "None" ]]; then fail "Route table $1 not found."; return 1; fi
  assoc=$(rtb_attr "$1" "Associations[?SubnetId!=null] | [0].SubnetId")
  if [[ "$assoc" == "$2" ]]; then
    pass "Route table $1 associated with $2: $id"
  else
    fail "Route table $1 association mismatch (assoc=$assoc, expected subnet $2): $id"
  fi
  echo "$id"
}
RT_A_PUBLIC=$(check_rtb_assoc ewb-rt-a-public "$(subnet_attr ewb-a-public SubnetId)")
RT_A_PRIVATE=$(check_rtb_assoc ewb-rt-a-private "$(subnet_attr ewb-a-private SubnetId)")
RT_B_PRIVATE=$(check_rtb_assoc ewb-rt-b-private "$(subnet_attr ewb-b-private SubnetId)")

# Peer routes present only in complete mode.
peer_route() { # $1=rtb id $2=dest cidr -> echoes pcx id or ""
  awsread ec2 describe-route-tables --route-table-ids "$1" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='$2'] | [0].VpcPeeringConnectionId" 2>/dev/null || true
}
igw_route() { # $1=rtb id
  awsread ec2 describe-route-tables --route-table-ids "$1" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].GatewayId' 2>/dev/null || true
}
if [[ -n "$RT_A_PUBLIC" ]]; then
  G=$(igw_route "$RT_A_PUBLIC")
  if [[ "$G" == "$IGW_A" ]]; then pass "Public route table has 0.0.0.0/0 -> $G"; else fail "Public route table 0.0.0.0/0 target is '$G' (expected IGW $IGW_A)."; fi
fi

check_peer_route() { # $1=rtb id $2=dest cidr $3=label
  local p
  if [[ -z "$1" ]]; then return 0; fi
  p=$(peer_route "$1" "$2")
  if [[ "$MODE" == "complete" ]]; then
    if [[ -n "$p" && "$p" != "None" ]]; then
      pass "Peer route $2 -> $p on $3."
    else
      fail "Missing peer route $2 on $3 (complete mode requires it)."
    fi
  else
    if [[ -n "$p" && "$p" != "None" ]]; then
      warn "Peer route $2 exists on $3 while deployment mode is staged (unexpected before the baseline test)."
    fi
  fi
}
check_peer_route "$RT_A_PRIVATE" 10.20.0.0/16 "private route table A"
check_peer_route "$RT_B_PRIVATE" 10.10.0.0/16 "private route table B"
check_peer_route "$RT_A_PUBLIC"  10.20.0.0/16 "public route table (bastion subnet)"

check_private_rtb_isolated() { # $1=rtb id
  local d
  if [[ -z "$1" ]]; then return 0; fi
  d=$(igw_route "$1")
  if [[ -n "$d" && "$d" != "None" ]]; then
    warn "Private route table $1 has an internet route ($d) - not allowed by this lab design."
  fi
}
check_private_rtb_isolated "$RT_A_PRIVATE"
check_private_rtb_isolated "$RT_B_PRIVATE"

# ------------------------------------------------------------------
# Security groups
# ------------------------------------------------------------------
echo
echo "-- Security groups --"
sg_attr() { # $1=tag $2=jmespath
  awsread ec2 describe-security-groups --filters "Name=group-name,Values=$1" \
      --query "SecurityGroups[0].$2" 2>/dev/null || true
}
BASTION_CIDR="${SOURCES_BASTION:-10.10.1.10/32}"
APP_A_CIDR="10.10.2.10/32"
APP_B_CIDR="10.20.1.10/32"

SG_BASTION=$(sg_attr ewb-sg-bastion "GroupId")
SG_APP_A=$(sg_attr ewb-sg-app-a "GroupId")
SG_APP_B=$(sg_attr ewb-sg-app-b "GroupId")
if [[ -z "$SG_BASTION" || "$SG_BASTION" == "None" ]]; then fail "Security group ewb-sg-bastion not found."; fi
if [[ -z "$SG_APP_A" || "$SG_APP_A" == "None" ]]; then fail "Security group ewb-sg-app-a not found."; fi
if [[ -z "$SG_APP_B" || "$SG_APP_B" == "None" ]]; then fail "Security group ewb-sg-app-b not found."; fi

if [[ -n "$SG_BASTION" && "$SG_BASTION" != "None" ]]; then
  SOURCES=$(sg_attr ewb-sg-bastion "IpPermissions[?IpProtocol=='tcp' && ToPort=='22'].IpRanges[].CidrIp" | tr '\t' '\n')
  echo "$SOURCES" | grep -q '0.0.0.0/0' && fail "ewb-sg-bastion allows SSH from 0.0.0.0/0 - forbidden by the lab rules."
  if [[ -n "$SOURCES" ]]; then
    pass "ewb-sg-bastion SSH source(s): $(echo $SOURCES | tr '\n' ' ')"
    note "Confirm this equals the administrator's current public IP /32."
  else
    fail "ewb-sg-bastion has no SSH ingress rule."
  fi
fi

check_app_sg() { # $1=sg tag $2=sg id $3=icmp source cidr
  local ssh_src icmp_src
  ssh_src=$(sg_attr "$1" "IpPermissions[?IpProtocol=='tcp' && ToPort=='22'].IpRanges[].CidrIp" | tr '\t' '\n' | head -1)
  icmp_src=$(sg_attr "$1" "IpPermissions[?IpProtocol=='icmp' && FromPort=='8'].IpRanges[].CidrIp" | tr '\t' '\n' | head -1)
  if [[ "$ssh_src" == "$BASTION_CIDR" ]]; then
    pass "$1 SSH source is the bastion private IP ($ssh_src): $2"
  else
    fail "$1 SSH source is '$ssh_src' (expected $BASTION_CIDR): $2"
  fi
  if [[ "$icmp_src" == "$3" ]]; then
    pass "$1 ICMP echo source is $icmp_src (type 8)."
  else
    fail "$1 ICMP echo source is '$icmp_src' (expected $3, type 8 code 0): $2"
  fi
}
[[ -n "$SG_APP_A" && "$SG_APP_A" != "None" ]] && check_app_sg ewb-sg-app-a "$SG_APP_A" "$APP_B_CIDR"
[[ -n "$SG_APP_B" && "$SG_APP_B" != "None" ]] && check_app_sg ewb-sg-app-b "$SG_APP_B" "$APP_A_CIDR"

# ------------------------------------------------------------------
# EC2 instances
# ------------------------------------------------------------------
echo
echo "-- EC2 instances --"
inst_attr() { # $1=tag $2=jmespath
  awsread ec2 describe-instances \
      --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running,pending,stopped" \
      --query "Reservations[0].Instances[0].$2" 2>/dev/null || true
}
check_instance() { # $1=tag $2=expected private ip $3=expected pub: any|none $4=expected sg name
  local id priv pub sg
  id=$(inst_attr "$1" "InstanceId")
  if [[ -z "$id" || "$id" == "None" ]]; then fail "Instance $1 not found (any state)."; return; fi
  priv=$(inst_attr "$1" "PrivateIpAddress")
  pub=$(inst_attr "$1" "PublicIpAddress")
  sg=$(inst_attr "$1" "SecurityGroups[0].GroupName")
  [[ "$pub" == "None" ]] && pub=""
  if [[ "$priv" == "$2" ]]; then pass "Instance $1 private IP is $priv: $id"; else fail "Instance $1 private IP is '$priv' (expected $2): $id"; fi
  if [[ "$3" == "none" && -n "$pub" && "$pub" != "None" ]]; then
    fail "Instance $1 has a public IP ($pub) - it must stay private."
  else
    pass "Instance $1 public IPv4: ${pub:-none}."
  fi
  if [[ "$sg" == "$4" ]]; then pass "Instance $1 uses security group $sg."; else warn "Instance $1 security group is '$sg' (expected $4)."; fi
}
check_instance ewb-bastion 10.10.1.10 any   ewb-sg-bastion
check_instance ewb-app-a   10.10.2.10 none ewb-sg-app-a
check_instance ewb-app-b   10.20.1.10 none ewb-sg-app-b

# ------------------------------------------------------------------
# VPC peering connection
# ------------------------------------------------------------------
echo
echo "-- VPC peering connection --"
if [[ -n "$VPC_A" && -n "$VPC_B" ]]; then
  PCX=$(awsread ec2 describe-vpc-peering-connections --filters "Name=tag:Name,Values=ewb-a-b-peer" \
        --query 'VpcPeeringConnections[0].{id:VpcPeeringConnectionId,status:Status.Code}' 2>/dev/null || true)
  if [[ -n "$PCX" && "$PCX" != "None" ]]; then
    PCX_ID=$(echo "$PCX" | awk '{print $1}')
    PCX_STATUS=$(echo "$PCX" | awk '{print $2}')
    if [[ "$MODE" == "complete" ]]; then
      if [[ "$PCX_STATUS" == "active" ]]; then pass "Peering ewb-a-b-peer is Active: $PCX_ID"
      else fail "Peering $PCX_ID status is '$PCX_STATUS' (expected 'active' in complete mode)."; fi
    else
      warn "Peering connection exists ($PCX_ID, status $PCX_STATUS) while mode is staged."
    fi
  elif [[ "$MODE" == "complete" ]]; then
    fail "No peering connection named ewb-a-b-peer found, but complete mode requires one."
  else
    pass "No peering connection present (correct for staged mode, pending baseline test)."
  fi
fi

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo
echo "======================================================"
echo " Summary: $PASS passed, $WARN warnings, $FAIL failed"
echo "======================================================"
if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL - review the [FAIL] lines above." >&2
  exit 1
fi
echo "RESULT: OK${WARN:+ (with $WARN warning(s))}"
exit 0
