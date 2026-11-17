#!/usr/bin/env bash
# docker-ufw.sh

# Ensure bash halts after fails
set -euo pipefail

# Find the folder this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the helper
. "$SCRIPT_DIR/lib/common.sh"

# Path to the reviewed ufw-docker script inside the repo.
UFW_DOCKER_SRC="$SCRIPT_DIR/vendor/ufw-docker"

# The source range that gets trusted.
DOCKER_SUBNETS="172.16.0.0/12"

require_root
require_ufw_active
require_docker

[[ -f "$UFW_DOCKER_SRC" ]] || die "Missing $UFW_DOCKER_SRC (the reviewed ufw-docker script)."

# Install the reviewed ufw-docker
log "Installing reviewed ufw-docker to /usr/local/bin"
install -m 0755 "$UFW_DOCKER_SRC" /usr/local/bin/ufw-docker
ok "installed"

# Back up and add the rules (skipped if already there)
if grep -q "BEGIN UFW AND DOCKER" /etc/ufw/after.rules; then
  log "ufw-docker rules already in after.rules, skipping"
  echo "    (To change subnets, restore the .bak files and re-run.)"
else
  log "Backing up UFW rule files"
  for f in /etc/ufw/after.rules /etc/ufw/after6.rules; do
    if [[ -e "$f.bak" ]]; then
      ok "$f.bak already exists, leaving it"
    else
      cp "$f" "$f.bak"
      ok "$f -> $f.bak"
    fi
  done
  log "Adding ufw-docker rules (trusted subnets: $DOCKER_SUBNETS)"
  ufw-docker install --docker-subnets "$DOCKER_SUBNETS"
fi

# Load and check
log "Restarting UFW"
systemctl restart ufw

log "Checking the DOCKER-USER chain"
iptables -L DOCKER-USER -n | grep -q "$DOCKER_SUBNETS" \
  || die "DOCKER-USER rules not loaded. Try a reboot, then re-run."
ok "rules loaded"

log "Done."
