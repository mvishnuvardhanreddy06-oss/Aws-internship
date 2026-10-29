#!/usr/bin/env bash
# Prints the workbook's ~/.ssh/config entries filled in from Terraform outputs.
#   scripts/generate-ssh-config.sh            print only
#   scripts/generate-ssh-config.sh --install  also add/replace a marked block in ~/.ssh/config (backup is made)
# Re-run it if the bastion public IP changes (for example after stop/start).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need terraform

BASTION_IP="$(tf_out bastion_public_ip)"
KEY_NAME="$(tf_out key_name)"
[[ -n "$BASTION_IP" ]] || die "No bastion public IP found. Run 'terraform apply' first."
[[ -n "$KEY_NAME" ]] || KEY_NAME="ewb-lab"

BLOCK="Host ewb-bastion
    HostName ${BASTION_IP}
    User ec2-user
    IdentityFile ~/.ssh/${KEY_NAME}.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/${KEY_NAME}.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/${KEY_NAME}.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion"

if [[ "${1:-}" != "--install" ]]; then
  echo "$BLOCK"
  echo
  echo "# Add the lines above to ~/.ssh/config, or run: scripts/generate-ssh-config.sh --install"
  exit 0
fi

START="# >>> ewb-vpc-peering >>>"
END="# <<< ewb-vpc-peering <<<"
CFG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
touch "$CFG"; chmod 600 "$CFG"
cp "$CFG" "$CFG.bak.$(date +%Y%m%d%H%M%S)"

TMP="$(mktemp)"
awk -v s="$START" -v e="$END" '$0==s{skip=1;next} $0==e{skip=0;next} !skip{print}' "$CFG" > "$TMP"
{ cat "$TMP"; echo; echo "$START"; echo "$BLOCK"; echo "$END"; } > "$CFG"
rm -f "$TMP"
chmod 600 "$CFG"
echo "Installed ewb-bastion / ewb-app-a / ewb-app-b into $CFG (previous file backed up as $CFG.bak.*)."
echo "Next: ssh ewb-bastion   (verify the host key fingerprint before typing yes), then: exit"
