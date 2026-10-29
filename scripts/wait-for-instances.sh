#!/usr/bin/env bash
# Waits until all three instances are running and pass their 2/2 status checks (workbook p.7).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need aws; need terraform

IDS=("$(tf_out instance_bastion_id)" "$(tf_out instance_app_a_id)" "$(tf_out instance_app_b_id)")
[[ -n "${IDS[0]}" ]] || die "No instances found in Terraform outputs. Run 'terraform apply' first."
echo "Waiting for status checks on: ${IDS[*]} (this can take 2-4 minutes)..."
aws_r ec2 wait instance-status-ok --instance-ids "${IDS[@]}"
echo "All three instances passed their status checks."
