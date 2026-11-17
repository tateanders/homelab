#!/usr/bin/env bash
# install-docker.sh
# Usage: sudo /srv/homelab/scripts/install-docker.sh

# Ensure bash halts after fails
set -euo pipefail

# Find the folder this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the helper
. "$SCRIPT_DIR/lib/common.sh"

require_root
require_debian

# Check for conflicting docker packages and print them out if found so the user can manually remove them
log "Checking for conflicting Docker packages"

conflicts="$(
  { dpkg-query -W -f='${db:Status-Status} ${Package}\n' \
      docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null || true; } \
    | awk '$1 == "installed" { print $2 }'
)"

[[ -z "$conflicts" ]] || die "Remove these packages first: $(echo "$conflicts" | tr '\n' ' ')"
ok "none found"

# add signing key and apt repo
log "Adding Docker's signing key and apt repo ($CODENAME)"
apt-get update -qq
apt-get install -y -qq ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update -qq
ok "repo added"

# Install docker engine and compose
log "Installing Docker Engine and Compose"
apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker containerd >/dev/null 2>&1
ok "$(docker --version)"
ok "$(docker compose version)"

# Test
log "Testing Docker with hello-world"
docker run --rm hello-world >/dev/null || die "hello-world failed."
ok "hello-world ran"

log "Docker install done. Don't publish container ports until docker-ufw.sh has run."
