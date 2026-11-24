#!/usr/bin/env bash
# lib/common.sh
#
# Shared helper functions for the homelab scripts.
# Load in scripts with:
#   . "$SCRIPT_DIR/lib/common.sh"

# Output helpers
log() { printf '\n==> %s\n' "$*"; }
ok()  { printf '    OK: %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# Pre-check functions
require_root() {
  [[ $EUID -eq 0 ]] || die "Requires sudo"
}

require_debian() {
  # make sure we are on Debian and get the codename (in my case it was trixie)
  . /etc/os-release
  [[ "${ID:-}" == "debian" ]] || die "This script is for Debian (found '${ID:-unknown}')."

  CODENAME="${VERSION_CODENAME:?Could not read Debian codename}"
  export CODENAME
}

require_ufw_active() {
  command -v ufw >/dev/null || die "UFW not installed"
  ufw status | grep -q "Status: active" || die "UFW not enabled"
}

require_docker() {
  command -v docker >/dev/null || die "Docker not installed"
  systemctl is-active --quiet docker || die "Docker not running"
}

require_tailscale() {
  command -v tailscale >/dev/null || die "Tailscale not installed"
  systemctl is-active --quiet tailscaled || die "tailscaled not running"
}
