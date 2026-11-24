#!/usr/bin/env bash
# tailscale-ufw.sh
# Usage: sudo /srv/homelab/scripts/tailscale-ufw.sh

# Ensure bash halts after fails
set -euo pipefail

# Find the folder this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the helper
. "$SCRIPT_DIR/lib/common.sh"

# The network interface Tailscale creates
TS_IFACE="tailscale0"

require_root
require_ufw_active
require_tailscale

# Make sure this machine is logged in to the tailnet
log "Checking Tailscale login"
tailscale ip -4 >/dev/null 2>&1 || die "Not logged in. Run: sudo tailscale up"
ok "logged in as $(tailscale ip -4)"

# Allow SSH on the Tailscale interface (ufw skips the rule if it already exists)
# The LAN rule (OpenSSH) is left alone as a fallback
log "Allowing SSH on $TS_IFACE"
ufw allow in on "$TS_IFACE" to any port 22 proto tcp comment 'SSH over Tailscale'

# Allow Tailscale's direct connection port (without it, traffic falls back to the slower relays)
log "Allowing Tailscale UDP 41641"
ufw allow 41641/udp comment 'Tailscale direct connections'

# Stop Tailscale from adding its own firewall rules (they let all tailnet traffic skip UFW)
log "Turning off Tailscale's firewall rules"
tailscale set --netfilter-mode=off

# Check
log "Checking UFW rules"
ufw status | grep -q "$TS_IFACE" || die "No $TS_IFACE rule in ufw status"
ufw status | grep -q "OpenSSH" || die "LAN SSH rule (OpenSSH) is missing"
ufw status | grep -q "41641/udp" || die "Tailscale UDP 41641 rule is missing"
! iptables -L ts-input -n >/dev/null 2>&1 || die "Tailscale's ts-input chain still exists (UFW bypass)"
ok "SSH allowed on $TS_IFACE and the LAN, UFW is filtering tailnet traffic"

log "Done."
