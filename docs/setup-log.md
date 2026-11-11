# Setup Log

## 2026-11-10 — Base install
- Installed Debian 13 on the 1 TB M.2 (hostname TateDeb)
- Why Debian: I used Debian due to it's stable update cycle, to have more control over what's installed on my homelab, and to gain practical experience in working with the setup and configuration of servers.

## 2026-11-11 — Basics, SSH, Git, Firewall
- Updated system, installed core packages, enabled unattended-upgrades
- Installed openssh-server, now managing from MacBook over SSH
- Created an ed25519 key for GitHub, cloned this repo to /srv/homelab
- Copied key to macbook for password-free ssh, then disabled pasword and root login via /etc/ssh/sshd_config.d/hardening.conf
- Verified that password login is refused using ssh -o PubkeyAuthentication=no user@ip
- Enabled Uncomplicated Firewall (UFW) allowing only SSH
