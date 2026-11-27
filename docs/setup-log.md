# Setup Log

What I did, in order, and why I made the choices I made. Steps to redo it are in rebuild.md.

## 2026-11-10 Base install

### What I did
- Installed Debian 13 on the 1 TB M.2 (hostname TateDeb)

### Decisions
- Why Debian: I used Debian due to its stable update cycle, to have more control over what's installed on my homelab, and to gain practical experience in working with the setup and configuration of servers.

## 2026-11-11 Basics, SSH, Git, Firewall

### What I did
- Updated system, installed core packages, enabled unattended-upgrades
- Installed openssh-server, now managing from MacBook over SSH
- Created an ed25519 key for GitHub, cloned this repo to `/srv/homelab`
- Copied key to MacBook for password-free SSH, then disabled password and root login via `/etc/ssh/sshd_config.d/hardening.conf`
- Enabled Uncomplicated Firewall (UFW) allowing only SSH
- Reserved `192.168.86.243` in Google Home app
- Masked all sleep and suspend targets so the PC can't go to sleep

### Testing
- Verified that password login is refused: `ssh -o PubkeyAuthentication=no user@ip`
- Verified networking and SSH come up on their own by rebooting and SSHing in from the MacBook

## 2026-11-13 Docker + UFW fix

### What I did
#### Docker Engine and Compose
- Installed from Docker's official apt repo
- Signing key: `/etc/apt/keyrings/docker.asc`
- Repo file: `/etc/apt/sources.list.d/docker.sources` (deb822 format)
- Packages: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
- Versions: Docker Engine 29.9.3, Compose v5.7.1
- docker and containerd are both enabled at boot

#### Making Docker respect UFW
- Docker writes its own firewall rules, so published container ports skip UFW and are open to the whole LAN
- Backed up `/etc/ufw/after.rules` and `after6.rules` to .bak before changing anything
- Downloaded the ufw-docker script (github.com/chaifeng/ufw-docker), reviewed it (no network calls besides man page links), and installed it to `/usr/local/bin/ufw-docker`
- Ran `sudo ufw-docker install --docker-subnets 172.16.0.0/12`
- Restarted UFW: `sudo systemctl restart ufw`

### Decisions
- I didn't add my user to the docker group. That group is basically root, so I use sudo for docker commands.
- The default ufw-docker install trusts 192.168.0.0/16, which includes my home LAN. Limiting it to Docker's subnet range means LAN devices get filtered.
- 172.16.0.0/12 covers the networks Docker creates later (like compose networks), so I don't need to rerun install for each new stack.

### Testing
- hello-world ran
- Ran a test nginx container on port 8080. curl from my Mac timed out.
- Saw the drops in the kernel log: `sudo journalctl -k | grep "UFW DOCKER BLOCK"`
- A container can still reach the internet (wget to example.com worked)
- Rebooted and checked that the DOCKER-USER rules came back: `sudo iptables -L DOCKER-USER -n -v`

### Notes for later
- To expose a container: `ufw route allow proto tcp from <source> to any port <container port>`
  - Use the container's internal port, not the published host port
- IPv6 is off in Docker, so ufw-docker skipped the IPv6 rules

## 2026-11-16 Scripts

### What I did
- Moved the Docker and UFW steps into scripts: `scripts/install-docker.sh` and `scripts/docker-ufw.sh`
- Shared checks (sudo, Debian, UFW, Docker) are in `scripts/lib/common.sh`
- Saved the ufw-docker copy I reviewed to `scripts/vendor/ufw-docker`

### Decisions
- docker-ufw.sh installs ufw-docker from the repo copy and doesn't download it. A rebuild runs the exact version I reviewed, not whatever is on GitHub that day.
- Kept it as separate scripts so I can redo one part without the other

## 2026-11-24 GRUB rescue fix (stale Kali bootloader)

### What happened
- Switched BIOS profiles and booted to `grub rescue>`. This also happened back when Kali was installed.
- Root cause: Kali's old GRUB was still at `/boot/efi/EFI/BOOT/BOOTX64.EFI` (the generic fallback path). The Debian installer reused the old EFI partition and left it there.
- The BIOS's "UEFI OS" entry launches that fallback file, so it was running Kali's GRUB, which looked for a partition that doesn't exist anymore
- Confirmed it was Kali's because the file was dated Jan 2026 and was the exact same size as `/boot/efi/EFI/kali/grubx64.efi` (147,456 bytes)

### What I did
#### Cleaning up the EFI partition
- Backed up the EFI folder: `sudo cp -r /boot/efi/EFI ~/efi-backup`
- Deleted the leftover Kali folder: `sudo rm -r /boot/efi/EFI/kali`
- Deleted the backup after testing: `sudo rm -r ~/efi-backup`

#### Replacing the fallback bootloader
- Set GRUB updates to also refresh the fallback copy: `echo "grub-efi-amd64 grub2/force_efi_extra_removable boolean true" | sudo debconf-set-selections`
- Installed Debian's bootloader to the fallback path: `sudo grub-install --force-extra-removable`
- `/boot/efi/EFI/BOOT/` now has Debian's shim as BOOTX64.EFI (1,036,152 bytes), plus grubx64.efi, mmx64.efi, and fbx64.efi

#### Cleaning up boot entries
- Listed entries with `sudo efibootmgr -v`. There were 2 "debian" entries and 1 "UEFI OS", all on the same EFI partition.
- Deleted the duplicates with `sudo efibootmgr -b <id> -B`
- Re-saved the Debian BIOS profile

### Decisions
- Kept the fallback bootloader instead of deleting it to get down to one entry. If the BIOS ever loses its boot entries (BIOS update, CMOS reset, profile load), "UEFI OS" still boots Debian, and Debian's fallback tool (fbx64.efi) recreates the "debian" entry.
- Leaving the extra "debian" entry for GRUBX64.EFI. The AORUS BIOS keeps re-adding it after reboots and profile loads. It points to Debian's GRUB, so it's harmless.

### Testing
- Booted through "UEFI OS" from Boot Override. Got a blue "Boot option restored" screen, picked "Continue boot," and it booted Debian.
- Normal reboot with Boot Option #1 set to "debian" works
- Switched to the Windows profile, booted Windows, switched back to the Debian profile. Debian still boots.

### Notes for later
- If boot ever breaks: F12 at startup, then pick "debian"
- The Windows BIOS profile still has the old boot entry snapshot. It's harmless now, but I could re-save it to match.

## 2026-11-24 Tailscale

### What I did
#### Installing Tailscale
- Tailscale is a private network between my devices built on WireGuard (an encrypted VPN protocol), so I can reach the homelab from anywhere without opening ports on the router
- Installed from Tailscale's official apt repo with `scripts/install-tailscale.sh`
- Signing key: `/usr/share/keyrings/tailscale-archive-keyring.gpg`
- Repo file: `/etc/apt/sources.list.d/tailscale.list`
- Version: 1.104.7
- tailscaled is enabled at boot
- Logged in with `sudo tailscale up`. TateDeb's Tailscale address is 100.xx.xx.xx.
- Disabled key expiry for TateDeb in the admin console
- Installed Tailscale on my Mac and logged in to the same account

#### Making Tailscale respect UFW
- Allowed SSH on tailscale0 with `scripts/tailscale-ufw.sh`
- Tested it by running `python3 -m http.server 9999` on TateDeb and curling it from my Mac over Tailscale. It loaded the page, even though UFW should have blocked 9999.
- Found the cause with `sudo iptables -L ts-input -n -v`. Tailscale adds its own chain (ts-input) with a rule that accepts everything on tailscale0, and it runs before UFW. So the SSH rule I added wasn't doing anything.
- Allowed Tailscale's direct connection port: `sudo ufw allow 41641/udp`
- Turned off Tailscale's firewall rules: `sudo tailscale set --netfilter-mode=off`
- Added both steps and checks for them to `scripts/tailscale-ufw.sh`

### Decisions
- Disabled key expiry because a server that needs me to log in again every few months would drop off the network without me noticing
- Kept LAN SSH allowed as a fallback. If Tailscale breaks I can still get in from the home Wi-Fi.
- Went with netfilter-mode off instead of Tailscale ACLs (access rules set in the admin console). This way UFW is the only firewall to manage, the same as how I handled Docker with ufw-docker. The tradeoff is that subnet routing or exit nodes would need firewall rules written by hand.
- Allowed UDP 41641 before turning netfilter off. Tailscale's rules were opening that port, and without it connections fall back to the slower relay servers.
- Free Personal plan, which is for non-commercial use

### Testing
- SSH from my Mac to 100.xx.xx.xx worked
- SSH worked with the Mac on a phone hotspot, but it was really laggy. Probably relayed because of the carrier's network.
- After the fix, the port 9999 test timed out and a new SSH connection over Tailscale still worked
- Re-ran `tailscale-ufw.sh` and it skipped the existing rules and passed its checks
- Rebooted and TateDeb rejoined on its own. SSH over Tailscale worked and `sudo iptables -L ts-input -n` still showed no chain.
- Ran a test nginx container on 8080 and curled 100.xx.xx.xx:8080 from my Mac. It timed out.

### Notes for later
- Run `tailscale ping 100.xx.xx.xx` from my Mac when I'm actually away from home to see if the connection is direct or relayed
- Nothing is reachable over Tailscale without a UFW rule now. Services need `ufw allow in on tailscale0 to any port <port> proto tcp`, and containers need `ufw route allow proto tcp from 100.64.0.0/10 to any port <container port>`.
