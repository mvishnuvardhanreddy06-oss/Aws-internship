#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts. Not meant to be run directly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
LOG_DIR="$REPO_ROOT/evidence/logs"
PROJECT_TAG="EWB-VPC-Peering"
mkdir -p "$LOG_DIR"

APP_A_IP="10.10.2.10"
APP_B_IP="10.20.1.10"

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."; }
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Read one Terraform output as a raw string (empty string if it is missing).
tf_out() { terraform -chdir="$TF_DIR" output -raw "$1" 2>/dev/null || true; }

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
if [[ -d "$TF_DIR/.terraform" ]]; then
  _r="$(tf_out region)"
  if [[ -n "$_r" ]]; then REGION="$_r"; fi
fi
aws_r() { aws --region "$REGION" "$@"; }

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
rssh() { ssh "${SSH_OPTS[@]}" "$@"; }

# The SSH aliases (ewb-bastion, ewb-app-a, ewb-app-b) come from generate-ssh-config.sh
require_ssh_config() {
  local got
  got="$(ssh -G ewb-app-a 2>/dev/null | awk '$1=="hostname"{print $2}')"
  [[ "$got" == "$APP_A_IP" ]] || die "SSH alias 'ewb-app-a' is not configured. Run: scripts/generate-ssh-config.sh --install"
}

# ping_test <ssh-host> <peer-ip> <loss|success>
# Runs the workbook command inside the host and checks the result.
# Returns 0 = expected result seen, 1 = unexpected result, 2 = could not run.
ping_test() {
  local host="$1" peer="$2" expect="$3" out
  echo "\$ ssh $host 'hostname; hostname -I; ping -c 4 $peer'"
  out="$(rssh "$host" "hostname; hostname -I; ping -c 4 $peer" 2>&1)" || true
  echo "$out"
  if ! grep -q 'packets transmitted' <<<"$out"; then
    echo "RESULT: ERROR - ping did not run (SSH problem?). First connect once by hand: ssh $host"
    return 2
  fi
  if [[ "$expect" == "loss" ]]; then
    if grep -q '100% packet loss' <<<"$out"; then
      echo "RESULT: PASS - no replies, as expected"; return 0
    fi
    echo "RESULT: FAIL - replies were received but none were expected"; return 1
  fi
  if grep -Eq ', 0% packet loss' <<<"$out"; then
    echo "RESULT: PASS - 4 replies, 0% packet loss"; return 0
  fi
  echo "RESULT: FAIL - expected 4 replies and 0% packet loss"; return 1
}
