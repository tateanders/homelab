#!/usr/bin/env bash
# install-tailscale.sh
# Usage: sudo /srv/homelab/scripts/install-tailscale.sh

# Ensure bash halts after fails
set -euo pipefail

# Find the folder this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the helper
. "$SCRIPT_DIR/lib/common.sh"

# Where Tailscale's packages live and where apt keeps the key and repo file
TS_REPO="https://pkgs.tailscale.com/stable/debian"
TS_KEYRING="/usr/share/keyrings/tailscale-archive-keyring.gpg"
TS_LIST="/etc/apt/sources.list.d/tailscale.list"

require_root
require_debian

# add signing key and apt repo
log "Adding Tailscale's signing key and apt repo ($CODENAME)"
apt-get update -qq
apt-get install -y -qq ca-certificates curl
install -m 0755 -d /usr/share/keyrings
curl -fsSL "$TS_REPO/$CODENAME.noarmor.gpg" -o "$TS_KEYRING"
chmod a+r "$TS_KEYRING"
curl -fsSL "$TS_REPO/$CODENAME.tailscale-keyring.list" -o "$TS_LIST"

# The repo file should only point at Tailscale and use the key above
grep -q "signed-by=$TS_KEYRING" "$TS_LIST" || die "$TS_LIST doesn't use the Tailscale key"
grep -q "pkgs.tailscale.com" "$TS_LIST" || die "$TS_LIST doesn't point at pkgs.tailscale.com"

apt-get update -qq
ok "repo added"

# Install tailscale and make sure the service starts at boot
log "Installing Tailscale"
apt-get install -y -qq tailscale
systemctl enable --now tailscaled >/dev/null 2>&1
ok "tailscale $(tailscale version | head -n 1)"

# Logging in needs a browser, so it stays a manual step
log "Checking login state"
if tailscale ip -4 >/dev/null 2>&1; then
  ok "already logged in as $(tailscale ip -4)"
  log "Tailscale install done."
else
  log "Tailscale install done. Not logged in yet, run: sudo tailscale up"
fi
