#!/usr/bin/env bash
# Creates the RSA key pair (default name: ewb-lab) and saves the .pem on THIS laptop only.
# Usage: scripts/create-key-pair.sh [key-name]
set -euo pipefail
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI is required." >&2; exit 1; }

KEY_NAME="${1:-ewb-lab}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-south-1}}"
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"

if [[ -e "$KEY_FILE" ]]; then
  echo "ERROR: $KEY_FILE already exists. Delete it first or choose another key name." >&2
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
umask 077
tmp="$(mktemp "$HOME/.ssh/.${KEY_NAME}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

aws --region "$REGION" ec2 create-key-pair \
  --key-name "$KEY_NAME" --key-type rsa --key-format pem \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Project,Value=EWB-VPC-Peering}]" \
  --query KeyMaterial --output text > "$tmp"

head -n 1 "$tmp" | grep -q -- '-----BEGIN' || { echo "ERROR: AWS did not return a private key." >&2; exit 1; }
mv "$tmp" "$KEY_FILE"
chmod 400 "$KEY_FILE"
trap - EXIT
echo "Created key pair '$KEY_NAME' in $REGION. Private key saved to $KEY_FILE (mode 400)."
echo "Never upload this file to an instance, to GitHub or into your report."
