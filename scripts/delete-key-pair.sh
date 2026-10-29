#!/usr/bin/env bash
# Cleanup step 1 (workbook p.14): remove the lab key pair from AWS and, if you agree, the local .pem.
# Usage: scripts/delete-key-pair.sh [key-name]
set -euo pipefail
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI is required." >&2; exit 1; }

KEY_NAME="${1:-ewb-lab}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"

aws --region "$REGION" ec2 delete-key-pair --key-name "$KEY_NAME"
echo "Deleted key pair '$KEY_NAME' from AWS ($REGION)."

if [[ -e "$KEY_FILE" ]]; then
  read -r -p "Also delete the local file $KEY_FILE ? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -f "$KEY_FILE"
    echo "Deleted $KEY_FILE"
  fi
fi
