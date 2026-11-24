# Rebuild Guide

How to rebuild TateDeb from a blank drive. Do the sections in order. Each one ends with a check so I know it worked before moving on.

- Commands run on TateDeb unless the step says "On the Mac"
- Anything in `<angle brackets>` is a value to fill in

## 1. BIOS and install

- Load the "debian" BIOS profile (SATA/Windows drive disabled)
- Install Debian 13 on the 1 TB M.2, hostname TateDeb
- In software selection: no desktop environment, check "SSH server"
- Connect to Wi-Fi during install

## 2. Updates and basics

```bash
sudo apt update && sudo apt full-upgrade
sudo apt install curl git htop ufw unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

## 3. SSH from the Mac

On the Mac:

```bash
ssh-keygen -R 192.168.86.243
ssh-copy-id tate@192.168.86.243
ssh tate@192.168.86.243
```

On TateDeb, create `/etc/ssh/sshd_config.d/hardening.conf` with:

```
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
```

Then check the config and restart SSH:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

Check: on the Mac, this should say "Permission denied":

```bash
ssh -o PubkeyAuthentication=no tate@192.168.86.243
```

## 4. Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw enable
```

Check: only OpenSSH should be listed.

```bash
sudo ufw status
```

## 5. Disable sleep

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## 6. GitHub and this repo

Make a key and add the public half to GitHub (Settings > SSH keys):

```bash
ssh-keygen -t ed25519 -C "tatedeb"
cat ~/.ssh/id_ed25519.pub
```

Check: this should greet me by username.

```bash
ssh -T git@github.com
```

Set up git and clone the repo:

```bash
git config --global user.name "Tate Christensen"
git config --global user.email "<github email>"
sudo mkdir -p /srv/homelab
sudo chown $USER:$USER /srv/homelab
git clone git@github.com:<github-user>/homelab.git /srv/homelab
```

## 7. Network

- IP reservation 192.168.86.243 is tied to the Wi-Fi card's MAC in the Google Home app
- It survives a reinstall, so nothing to redo unless the Wi-Fi card changes

## 8. Base layer check

```bash
sudo reboot
```

Check: SSH in from the Mac without touching the PC.

## 9. Bootloader / EFI

Makes sure the fallback bootloader is Debian's, so switching BIOS profiles can't send me to the GRUB rescue screen.

Check: only `debian` and `BOOT` should be listed. If anything else shows up, see the 2026-11-24 GRUB entry in the setup log.

```bash
sudo ls /boot/efi/EFI
```

Make GRUB updates keep the fallback bootloader current, then install Debian's bootloader to the fallback path:

```bash
echo "grub-efi-amd64 grub2/force_efi_extra_removable boolean true" | sudo debconf-set-selections
sudo grub-install --force-extra-removable
```

Check 1, fallback is Debian's. `BOOTX64.EFI` should have today's date and be the same size as `/boot/efi/EFI/debian/shimx64.efi`:

```bash
sudo ls -l /boot/efi/EFI/BOOT
```

Check 2, boot entries. Every entry should point to `\EFI\debian\` or `\EFI\BOOT\`:

```bash
sudo efibootmgr -v
```

In the BIOS, set Boot Option #1 to "debian" and re-save both profiles.

**Notes**
- The AORUS BIOS re-adds a "debian" entry for `GRUBX64.EFI` plus a "UEFI OS" entry. That's expected and both boot Debian, so don't bother deleting them.
- The first boot through "UEFI OS" shows a blue "Boot option restored" screen. Pick "Continue boot."
- Recovery: F12 at startup, then pick "debian."

## 10. Install Docker

Script: `scripts/install-docker.sh` (safe to re-run). Installs Docker Engine and Compose from Docker's apt repo and runs hello-world.

```bash
sudo /srv/homelab/scripts/install-docker.sh
```

Check: the script ends with "Docker install done".

## 11. Make Docker respect UFW

Script: `scripts/docker-ufw.sh` (safe to re-run). Installs the reviewed copy of ufw-docker from `scripts/vendor/` and adds its rules, trusting only 172.16.0.0/12.

```bash
sudo /srv/homelab/scripts/docker-ufw.sh
```

Check 1, LAN block. Start a test container:

```bash
sudo docker run -d --rm --name ufwtest -p 8080:80 nginx:alpine
```

On the Mac (should time out):

```bash
curl -m 5 http://192.168.86.243:8080
```

Back on TateDeb, the drop should be in the log. Then stop the container:

```bash
sudo journalctl -k --since "5 min ago" | grep "UFW DOCKER BLOCK"
sudo docker stop ufwtest
```

Check 2, container internet (should print the Example Domain HTML):

```bash
sudo docker run --rm alpine wget -qO- -T 5 https://example.com
```

Check 3, reboot. The DOCKER-USER chain should still have the rules and say "1 references":

```bash
sudo reboot
sudo iptables -L DOCKER-USER -n -v
```

**Notes**
- To expose a container: `sudo ufw route allow proto tcp from <source> to any port <container port>`. Use the container's internal port, not the published one.
- If ufw-docker ever needs an update, download it, review it again, then replace the copy in `scripts/vendor/`.

## 12. Install Tailscale

Script: `scripts/install-tailscale.sh` (safe to re-run). Adds Tailscale's apt repo, installs it, and enables the tailscaled service.

```bash
sudo /srv/homelab/scripts/install-tailscale.sh
```

Log in. This prints a URL, open it on the Mac and approve TateDeb:

```bash
sudo tailscale up
```

In the Tailscale admin console (login.tailscale.com/admin/machines):

- If an old TateDeb is listed from before the rebuild, remove it
- Open the menu next to TateDeb and disable key expiry, so the server doesn't drop off the tailnet when the key runs out

Check: this should print a 100.x.x.x address.

```bash
tailscale ip -4
```

## 13. Tailscale firewall + SSH over Tailscale

Script: `scripts/tailscale-ufw.sh` (safe to re-run). It does three things:
- Allows SSH on the tailscale0 interface. LAN SSH stays allowed as a fallback.
- Allows UDP 41641 (Tailscale's direct connection port). Without it, traffic falls back to Tailscale's slower relay servers.
- Turns off Tailscale's own firewall rules (`netfilter-mode=off`). By default Tailscale adds a rule that accepts everything on tailscale0 before UFW sees it, so every port is open to the tailnet.

```bash
sudo /srv/homelab/scripts/tailscale-ufw.sh
```

The "netfilter=off; configure iptables yourself" warning is expected.

On the Mac: install Tailscale and log in to the same account.

Check 1, SSH over Tailscale. On the Mac:

```bash
ssh tate@<tailscale ip>
```

Check 2, off the home Wi-Fi. Put the Mac on a phone hotspot and run the same SSH command. It can be laggy because hotspots usually force Tailscale onto its relays. `tailscale ping <tailscale ip>` on the Mac shows whether it's direct or relayed.

Check 3, UFW blocks tailnet traffic. On TateDeb:

```bash
python3 -m http.server 9999
```

On the Mac (should time out):

```bash
curl -m 5 http://<tailscale ip>:9999
```

Stop the server with Ctrl+C. If the curl loads a directory listing, Tailscale is bypassing UFW. Check for its rules with `sudo iptables -L ts-input -n -v` and rerun the script.

Check 4, reboot. TateDeb should rejoin on its own and the bypass should stay off:

```bash
sudo reboot
tailscale status
sudo iptables -L ts-input -n
```

The last command should say `No chain/target/match by that name`.

Check 5, containers over Tailscale. Run the LAN block test from section 11, but curl the Tailscale address from the Mac (should time out):

```bash
curl -m 5 http://<tailscale ip>:8080
```

Result on the last build: timed out (2026-11-24)

**Notes**
- To expose a container to the tailnet: `sudo ufw route allow proto tcp from 100.64.0.0/10 to any port <container port>`
- To expose a non-Docker service to the tailnet: `sudo ufw allow in on tailscale0 to any port <port> proto tcp`
- With netfilter off, Tailscale's anti-spoofing rule is gone too (it dropped Tailscale addresses that didn't arrive on tailscale0). That's low risk on a home LAN.

## Possibly in the future
- Immich
- Backups (restic or Borg)
- Caddy
