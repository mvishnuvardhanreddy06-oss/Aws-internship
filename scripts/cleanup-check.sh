#!/usr/bin/env bash
# Run AFTER 'terraform destroy' (and delete-key-pair.sh). Lists anything still tagged
# Project=EWB-VPC-Peering and fails if something is left or a query cannot be run.
# Evidence: evidence/logs/07-cleanup.txt
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need aws

TAGF="Name=tag:Project,Values=$PROJECT_TAG"

# check <label> <command...> : run the AWS query; print OK, LEFTOVER or QUERY FAILED
check() {
  local label="$1" items
  shift
  if ! items="$("$@" 2>&1)"; then
    printf '%-34s QUERY FAILED: %s\n' "$label" "$items"
    return
  fi
  if [[ -z "$items" || "$items" == "None" ]]; then
    printf '%-34s OK (none found)\n' "$label"
  else
    printf '%-34s LEFTOVER: %s\n' "$label" "$(echo "$items" | tr '\n\t' '  ')"
  fi
}

run() {
  echo "# Cleanup verification - $(ts) - Region $REGION - tag Project=$PROJECT_TAG"
  echo
  check "EC2 instances (not terminated)" aws_r ec2 describe-instances --filters "$TAGF" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' --output text
  check "EBS volumes" aws_r ec2 describe-volumes --filters "$TAGF" --query 'Volumes[].VolumeId' --output text
  check "EBS snapshots (owned by you)" aws_r ec2 describe-snapshots --owner-ids self --filters "$TAGF" \
    --query 'Snapshots[].SnapshotId' --output text
  check "Elastic IPs" aws_r ec2 describe-addresses --filters "$TAGF" --query 'Addresses[].AllocationId' --output text
  check "Peering connections (live)" aws_r ec2 describe-vpc-peering-connections --filters "$TAGF" \
    "Name=status-code,Values=pending-acceptance,provisioning,active" \
    --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text
  check "Security groups" aws_r ec2 describe-security-groups --filters "$TAGF" --query 'SecurityGroups[].GroupId' --output text
  check "Route tables" aws_r ec2 describe-route-tables --filters "$TAGF" --query 'RouteTables[].RouteTableId' --output text
  check "Subnets" aws_r ec2 describe-subnets --filters "$TAGF" --query 'Subnets[].SubnetId' --output text
  check "Internet gateways" aws_r ec2 describe-internet-gateways --filters "$TAGF" \
    --query 'InternetGateways[].InternetGatewayId' --output text
  check "VPCs" aws_r ec2 describe-vpcs --filters "$TAGF" --query 'Vpcs[].VpcId' --output text
  check "Key pair (project tag)" aws_r ec2 describe-key-pairs --filters "$TAGF" --query 'KeyPairs[].KeyName' --output text
  echo
  echo "@@DECIDE@@"
}

run 2>&1 | tee "$LOG_DIR/07-cleanup.txt" >/dev/null

# Decide from the saved lines (the checks ran in a pipeline subshell).
LOG="$LOG_DIR/07-cleanup.txt"
if grep -Eq 'LEFTOVER|QUERY FAILED' "$LOG"; then
  sed -i 's/^@@DECIDE@@$/RESULT: FAIL - delete the leftovers (or fix the failed query), then run this script again/' "$LOG"
  rc=1
else
  sed -i 's/^@@DECIDE@@$/RESULT: PASS - no resources tagged Project='"$PROJECT_TAG"' remain in '"$REGION"'\nReminder: also check the Billing console; usage reporting can lag./' "$LOG"
  rc=0
fi
cat "$LOG"
echo "(saved to evidence/logs/07-cleanup.txt)"
exit "$rc"
