#!/usr/bin/env bash
# Workbook p.11 "Run a controlled failure":
#   1. ping App-B from App-A (works)          2. remove ONLY the App-B inbound ICMP Echo rule
#   3. ping again (must fail; SSH must still work)
#   4. restore the exact rule                 5. ping again (must work)
# The rule is removed/restored through Terraform so state never drifts.
# Do not mix this with manual console edits of the same rule.
# Evidence: evidence/logs/06-controlled-failure.txt
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need terraform; need ssh; need aws
require_ssh_config

PEER_ID="$(tf_out peering_id)"
[[ -n "$PEER_ID" ]] || die "Peering is not enabled. Set enable_peering = true in terraform.tfvars and apply first."

tf_apply() { # $1 = true|false -> app_b_icmp_enabled
  terraform -chdir="$TF_DIR" apply -auto-approve -input=false -no-color \
    -var "enable_peering=true" -var "app_b_icmp_enabled=$1" 2>&1 | tail -n 8
}

restore_rule() {
  if [[ "${REMOVED:-0}" -eq 1 ]]; then
    echo
    echo "!! Restoring the App-B ICMP rule before exiting..."
    tf_apply true || echo "!! Could not restore automatically. Run: terraform -chdir=terraform apply -var enable_peering=true"
    REMOVED=0
  fi
}

scenario() {
  local fail=0
  REMOVED=0
  trap restore_rule EXIT

  echo "# Controlled failure test - $(ts)"
  echo "# Peering connection: $PEER_ID"
  echo
  echo "## Step 1 - BEFORE: rule present, ping must work"
  ping_test ewb-app-a "$APP_B_IP" success || fail=1

  echo
  echo "## Step 2 - Remove ONLY the ewb-sg-app-b inbound ICMP Echo request rule (source $APP_A_IP/32)"
  echo "\$ terraform apply -var enable_peering=true -var app_b_icmp_enabled=false"
  REMOVED=1
  tf_apply false
  echo "Waiting 20 seconds for the change to take effect..."
  sleep 20

  echo
  echo "## Step 3 - DURING failure: ping must get no replies, SSH rule is untouched"
  ping_test ewb-app-a "$APP_B_IP" loss || fail=1
  if rssh ewb-app-b 'echo "SSH to App-B still works (SSH rule kept in place)"' 2>&1; then
    echo "RESULT: PASS - SSH rule still in place"
  else
    echo "RESULT: FAIL - SSH to App-B stopped working"; fail=1
  fi

  echo
  echo "## Step 4 - Restore the exact rule"
  echo "\$ terraform apply -var enable_peering=true -var app_b_icmp_enabled=true"
  tf_apply true
  REMOVED=0
  echo "Waiting 10 seconds..."
  sleep 10

  echo
  echo "## Step 5 - AFTER restore: ping must work again"
  ping_test ewb-app-a "$APP_B_IP" success || fail=1

  echo
  if [[ $fail -eq 0 ]]; then
    echo "SUMMARY: PASS - replies, then no replies without the rule, then replies after restoring it"
  else
    echo "SUMMARY: FAIL - see the RESULT lines above"
  fi
  return "$fail"
}

rc=0
scenario 2>&1 | tee "$LOG_DIR/06-controlled-failure.txt" || rc=$?
echo "(saved to evidence/logs/06-controlled-failure.txt)"
exit "$rc"
