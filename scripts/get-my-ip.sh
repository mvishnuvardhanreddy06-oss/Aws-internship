#!/usr/bin/env bash
# Prints your current public IPv4 as a /32 for terraform.tfvars (my_ip_cidr).
set -euo pipefail
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }
ip="$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "ERROR: could not determine a public IPv4 address (got: '$ip')." >&2
  exit 1
fi
echo "${ip}/32"
