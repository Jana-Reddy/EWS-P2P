# Safety rules enforced by this script (README section 14):
#   * Checks that the SSH private key exists. Its contents are never read.
#   * Never invents a bastion public IP: only replaces the placeholder
#     when an IP is explicitly provided with --bastion-ip (or EWB_BASTION_IP).
#   * Never overwrites an existing SSH configuration without confirmation
#     (--force skips the prompt).
#   * Only touches a marked block (between BEGIN/END markers); all other
#     entries in the config file are preserved unchanged.
#   * Supports a safe --dry-run preview.
#
# Usage:
#   ./scripts/configure-ssh.sh --bastion-ip <PUBLIC_IP>            # apply
#   ./scripts/configure-ssh.sh --bastion-ip <PUBLIC_IP> --dry-run  # preview
#   ./scripts/configure-ssh.sh --help
#
# Options:
#   --bastion-ip <IP>   Current public IPv4 of the bastion. Get it with:
#                       terraform output -raw bastion_public_ip
#   --config <PATH>     SSH config to update (default: ~/.ssh/config)
#   --key <PATH>        Private key for the lab (default: ~/.ssh/ewb-lab.pem)
#   --dry-run           Preview the managed block without writing anything
#   --force             Replace non-managed ewb-* entries without prompting
#   --help | -h         Show this help
#
# Optional environment overrides (defaults follow the documented plan):
#   EWB_BASTION_IP (like --bastion-ip)
#   EWB_APP_A_IP (default 10.10.2.10), EWB_APP_B_IP (default 10.20.1.10)

set -euo pipefail

DRY_RUN=false
FORCE=false
BASTION_IP="${EWB_BASTION_IP:-}"
KEY_PATH="${HOME:-.}/.ssh/ewb-lab.pem"
CONFIG_PATH="${HOME:-.}/.ssh/config"
APP_A_IP="${EWB_APP_A_IP:-10.10.2.10}"
APP_B_IP="${EWB_APP_B_IP:-10.20.1.10}"

BEGIN_MARK="# >>> EWB VPC Peering lab (managed by scripts/configure-ssh.sh) >>>"
END_MARK="# <<< EWB VPC Peering lab <<<"

usage() { sed -n '2,28p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bastion-ip) BASTION_IP="${2:?--bastion-ip needs a value}"; shift 2 ;;
    --config)     CONFIG_PATH="${2:?--config needs a value}";   shift 2 ;;
    --key)        KEY_PATH="${2:?--key needs a value}";         shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --force)      FORCE=true; shift ;;
    --help|-h)    usage ;;
    *) echo "ERROR: unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done

# Portable file-mode lookup (GNU stat vs BSD stat).
mode_of() {
  local m=""
  m=$(stat -c '%a' "$1" 2>/dev/null) || m=$(stat -f '%Lp' "$1")
  printf '%s' "$m"
}

build_block() {
  cat <<EOF

${BEGIN_MARK}
Host ewb-bastion
    HostName ${BASTION_IP}
    User ec2-user
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes

Host ewb-app-a
    HostName ${APP_A_IP}
    User ec2-user
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName ${APP_B_IP}
    User ec2-user
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes
    ProxyJump ewb-bastion
${END_MARK}
EOF
}

# Print the config content WITHOUT the managed block.
strip_block() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" 'index($0, b) == 1 { skip=1; next }
                                           index($0, e) == 1 { skip=0; next }
                                           !skip { print }' "$1"
}

ips_are_valid=true
for ip in "$APP_A_IP" "$APP_B_IP"; do
  echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || ips_are_valid=false
done
if [[ "$ips_are_valid" != true ]]; then
  echo "ERROR: EWB_APP_A_IP / EWB_APP_B_IP must be IPv4 addresses." >&2
  exit 2
fi

# Step 1: private key existence and permissions.
echo "[1/4] Checking the private key ..."
if [[ -f "$KEY_PATH" ]]; then
  mode=$(mode_of "$KEY_PATH")
  case "$mode" in
    400|600)
      echo "      OK: $KEY_PATH exists (permissions: $mode).";;
    *)
      echo "      WARNING: $KEY_PATH permissions are $mode."
      if [[ "$DRY_RUN" == true ]]; then
        echo "      Dry-run: would fix with: chmod 400 \"$KEY_PATH\""
      else
        chmod 400 "$KEY_PATH"
        echo "      Fixed: permissions set to 400."
      fi;;
  esac
else
  if [[ "$DRY_RUN" == true ]]; then
    echo "      DRY-RUN note: apply mode requires a private key at $KEY_PATH."
    echo "      Create it first - README section 11: ssh-keygen -t ed25519 -f \"$KEY_PATH\""
  else
    echo "ERROR: private key not found at $KEY_PATH." >&2
    echo "       Create/import the key pair first (README section 11). The private" >&2
    echo "       key stays local and is never uploaded to AWS." >&2
    exit 2
  fi
fi

# Step 2: bastion IP. Never invented; only replaced when explicitly given.
echo "[2/4] Checking the bastion public IPv4 ..."
if [[ -z "$BASTION_IP" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "      DRY-RUN note: no --bastion-ip given, preview keeps placeholder."
    BASTION_IP="BASTION_PUBLIC_IP"
  else
    echo "ERROR: an explicit bastion public IP is required in apply mode." >&2
    echo "       Get it with: terraform output -raw bastion_public_ip" >&2
    exit 2
  fi
else
  echo "      Bastion public IP: $BASTION_IP"
fi

# Step 3: inspect the existing config.
echo "[3/4] Checking the SSH configuration ..."
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "      $CONFIG_PATH does not exist yet; it will be created."
  existing_dups=""
else
  existing_dups=$(strip_block "$CONFIG_PATH" | grep -nE '^[[:space:]]*Host[[:space:]].*ewb-(bastion|app-a|app-b)' || true)
  if [[ -n "$existing_dups" ]]; then
    echo "      Found ewb-* Host entries OUTSIDE the managed block:"
    echo "$existing_dups" | sed 's/^/        /'
    if [[ "$DRY_RUN" == true ]]; then
      echo "      DRY-RUN note: applying would ask (or --force) to replace them."
    elif [[ "$FORCE" == true ]]; then
      echo "      --force: those stray entries will be removed in favour of the managed block."
    elif [[ -t 0 ]]; then
      printf "      Replace these stray entries with the managed block? [y/N] "
      read -r reply
      if [[ "$reply" != "y" && "$reply" != "Y" ]]; then
        echo "Aborted. Nothing was changed." >&2
        exit 3
      fi
    else
      echo "ERROR: existing stray entries found and no TTY available for the" >&2
      echo "       confirmation prompt. Rerun with --force if replacement is intended." >&2
      exit 3
    fi
  else
    echo "      No conflicting ewb-* entries outside the managed block."
  fi
  if grep -qF "$BEGIN_MARK" "$CONFIG_PATH"; then
    echo "      The file already contains the managed block; it will be updated in place."
  fi
fi

# Step 4: write or preview.
echo "[4/4] Result ..."
if [[ "$DRY_RUN" == true ]]; then
  echo "      DRY-RUN: the managed block below would be written to $CONFIG_PATH"
  echo "      ---------- managed block preview ----------"
  build_block
  echo "      --------------------------------------------"
else
  mkdir -p "$(dirname "$CONFIG_PATH")"
  tmp=$(mktemp)
  {
    strip_block "$CONFIG_PATH" 2>/dev/null || true
    build_block
  } > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
  if ! grep -qF "$BEGIN_MARK" "$CONFIG_PATH"; then
    echo "ERROR: configuration write failed verification." >&2
    exit 2
  fi
  echo "      OK: $CONFIG_PATH (permissions $(mode_of "$CONFIG_PATH"))."
  echo "      Managed block written; other entries were preserved."
fi

echo
echo "Next steps:"
echo "  ssh ewb-bastion 'hostname'      # sanity check the bastion"
echo "  ssh ewb-app-a   'hostname -I'"  # example private-host check
echo "  ./scripts/verify-connectivity.sh a2b --expect-fail   # baseline (pre-peering)"
if [[ "$DRY_RUN" == false && -n "$existing_dups" ]]; then
  echo
  echo "Stray ewb-* entries outside the managed block were removed:"
  echo "$existing_dups" | sed 's/^/  /'
fi
