#!/usr/bin/env bash
# Saves resource inventory, subnets, route tables (with associations), security-group
# inbound rules and the peering connection as text evidence.
#   scripts/collect-inventory.sh before   -> evidence/logs/00a-inventory-before-peering.txt
#   scripts/collect-inventory.sh after    -> evidence/logs/00b-inventory-after-peering.txt
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need aws; need terraform

WHEN="${1:-}"
case "$WHEN" in
  before) OUT="$LOG_DIR/00a-inventory-before-peering.txt" ;;
  after)  OUT="$LOG_DIR/00b-inventory-after-peering.txt" ;;
  *) die "Usage: scripts/collect-inventory.sh <before|after>" ;;
esac

terraform -chdir="$TF_DIR" output -json > "$REPO_ROOT/evidence/terraform-outputs.json"

report() {
  echo "# Inventory ($WHEN peering) - collected $(ts) - Region $REGION"
  echo
  echo "## VPCs"
  aws_r ec2 describe-vpcs --filters "Name=tag:Project,Values=$PROJECT_TAG" \
    --query "Vpcs[].[Tags[?Key=='Name']|[0].Value,VpcId,CidrBlock,State]" --output table
  echo
  echo "## Subnets"
  aws_r ec2 describe-subnets --filters "Name=tag:Project,Values=$PROJECT_TAG" \
    --query "Subnets[].[Tags[?Key=='Name']|[0].Value,SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]" --output table
  echo
  echo "## Internet gateway"
  aws_r ec2 describe-internet-gateways --filters "Name=tag:Project,Values=$PROJECT_TAG" \
    --query "InternetGateways[].[Tags[?Key=='Name']|[0].Value,InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]" --output table
  echo
  echo "## Route tables (subnet associations and routes)"
  local pair name outkey id sid
  for pair in "ewb-rt-a-public:rt_a_public_id" "ewb-rt-a-private:rt_a_private_id" "ewb-rt-b-private:rt_b_private_id"; do
    name="${pair%%:*}"; outkey="${pair##*:}"; id="$(tf_out "$outkey")"
    echo
    echo "### $name ($id)"
    echo "Associated subnets:"
    for sid in $(aws_r ec2 describe-route-tables --route-table-ids "$id" \
        --query "RouteTables[0].Associations[?SubnetId!=null].SubnetId" --output text); do
      aws_r ec2 describe-subnets --subnet-ids "$sid" \
        --query "Subnets[0].[Tags[?Key=='Name']|[0].Value,SubnetId,CidrBlock]" --output text
    done
    aws_r ec2 describe-route-tables --route-table-ids "$id" \
      --query "RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId,State]" --output table
  done
  echo
  echo "## Security groups (inbound rules)"
  for pair in "ewb-sg-bastion:sg_bastion_id" "ewb-sg-app-a:sg_app_a_id" "ewb-sg-app-b:sg_app_b_id"; do
    name="${pair%%:*}"; outkey="${pair##*:}"; id="$(tf_out "$outkey")"
    echo
    echo "### $name ($id)   [for ICMP: FromPort = type, ToPort = code]"
    aws_r ec2 describe-security-groups --group-ids "$id" \
      --query "SecurityGroups[0].IpPermissions[].[IpProtocol,FromPort,ToPort,join(', ',IpRanges[].CidrIp)]" --output table
  done
  echo
  echo "## Peering connection"
  id="$(tf_out peering_id)"
  if [[ -n "$id" ]]; then
    aws_r ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$id" \
      --query "VpcPeeringConnections[0].[Tags[?Key=='Name']|[0].Value,VpcPeeringConnectionId,Status.Code,RequesterVpcInfo.VpcId,RequesterVpcInfo.CidrBlock,AccepterVpcInfo.VpcId,AccepterVpcInfo.CidrBlock]" --output table
  else
    echo "(no peering connection yet - this is the stage-1 / baseline state)"
  fi
  echo
  echo "## Instances"
  aws_r ec2 describe-instances --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress,State.Name]" --output table
}

report 2>&1 | tee "$OUT"
echo
echo "Saved $OUT and evidence/terraform-outputs.json"
