#!/usr/bin/env bash
# Runs the workbook's verification tests from your laptop and saves the output as evidence.
#   scripts/run-tests.sh baseline       Test 01 - BEFORE peering: ping App-B from App-A must fail
#   scripts/run-tests.sh after-peering  Tests 02-05 - forward ping, reverse ping, App-B SSH, isolation
#   scripts/run-tests.sh forward|reverse|ssh|isolation   run one test
# First connect once by hand (ssh ewb-bastion, ssh ewb-app-a, later ssh ewb-app-b) and verify
# each host key; these tests run non-interactively and will not accept host keys for you.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need ssh; need aws; need terraform
require_ssh_config

test_baseline() {
  echo "# Test 01 - Baseline (before peering) - $(ts)"
  echo "# Expected: App-A cannot reach App-B (no peering, no route)"
  ping_test ewb-app-a "$APP_B_IP" loss
}

test_forward() {
  echo "# Test 02 - Forward path (App-A -> App-B, after routes) - $(ts)"
  echo "# Expected: 4 replies, 0% packet loss"
  ping_test ewb-app-a "$APP_B_IP" success
}

test_reverse() {
  echo "# Test 03 - Reverse path (App-B -> App-A, after routes) - $(ts)"
  echo "# Expected: 4 replies, 0% packet loss"
  ping_test ewb-app-b "$APP_A_IP" success
}

test_ssh() {
  local out
  echo "# Test 04 - Private SSH to App-B through the bastion (ProxyJump) - $(ts)"
  echo "# Effective SSH settings for ewb-app-b:"
  ssh -G ewb-app-b | grep -Ei '^(hostname|user|proxyjump) ' || true
  echo "\$ ssh ewb-app-b 'hostname; hostname -I'"
  out="$(rssh ewb-app-b 'hostname; hostname -I; echo "shell on App-B reached through the bastion"' 2>&1)" || true
  echo "$out"
  if grep -q 'shell on App-B reached' <<<"$out"; then
    echo "RESULT: PASS - shell on App-B through bastion"; return 0
  fi
  echo "RESULT: FAIL - could not reach App-B. See docs/TROUBLESHOOTING-AND-VIVA.md (App-B SSH fails)"; return 1
}

test_isolation() {
  local name pub seen=0 rc=0
  echo "# Test 05 - Isolation: App-A and App-B must have no public IPv4 - $(ts)"
  aws_r ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress]" \
    --output table
  while IFS=$'\t' read -r name _ _ pub; do
    case "$name" in
      ewb-app-a|ewb-app-b)
        seen=$((seen + 1))
        if [[ -n "$pub" && "$pub" != "None" ]]; then
          echo "RESULT: FAIL - $name has public IPv4 $pub"; rc=1
        fi ;;
    esac
  done < <(aws_r ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress]" \
    --output text)
  if [[ $seen -ne 2 ]]; then echo "RESULT: FAIL - expected to find ewb-app-a and ewb-app-b running"; rc=1; fi
  [[ $rc -eq 0 ]] && echo "RESULT: PASS - no public IPv4 on App-A or App-B"
  return $rc
}

# run_logged <logfile-name> <function>  : show output and save it as evidence
run_logged() {
  local file="$LOG_DIR/$1" fn="$2" rc=0
  "$fn" 2>&1 | tee "$file" || rc=$?
  echo "(saved to evidence/logs/$1)"
  echo
  return "$rc"
}

rc=0
case "${1:-}" in
  baseline)  run_logged 01-baseline.txt test_baseline || rc=1 ;;
  forward)   run_logged 02-forward-path.txt test_forward || rc=1 ;;
  reverse)   run_logged 03-reverse-path.txt test_reverse || rc=1 ;;
  ssh)       run_logged 04-private-ssh.txt test_ssh || rc=1 ;;
  isolation) run_logged 05-isolation.txt test_isolation || rc=1 ;;
  after-peering)
    run_logged 02-forward-path.txt test_forward || rc=1
    run_logged 03-reverse-path.txt test_reverse || rc=1
    run_logged 04-private-ssh.txt test_ssh || rc=1
    run_logged 05-isolation.txt test_isolation || rc=1 ;;
  *) die "Usage: scripts/run-tests.sh <baseline|after-peering|forward|reverse|ssh|isolation>" ;;
esac

if [[ $rc -eq 0 ]]; then echo "ALL REQUESTED TESTS PASSED"; else echo "ONE OR MORE TESTS FAILED"; fi
exit "$rc"
