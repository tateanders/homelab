## 1. BIOS and install
- Load the "debian" BIOS profile (SATA/Windows drive disabled)
- Install Debian 13 on the 1 TB M.2, hostname TateDeb
- In software selection: no desktop environment, check "SSH server"
- Connect to Wi-Fi during install

## 2. Updates and basics
sudo apt update && sudo apt full-upgrade
sudo apt install curl git htop ufw unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

## 3. SSH from the Mac
On the Mac:
ssh-keygen -R 192.168.86.243
ssh-copy-id tate@192.168.86.243
ssh tate@192.168.86.243

On TateDeb, create /etc/ssh/sshd_config.d/hardening.conf:
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no

Then:
sudo sshd -t
sudo systemctl restart ssh

Verify from the Mac (should say Permission denied):
ssh -o PubkeyAuthentication=no tate@192.168.86.243

## 4. Firewall
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status

## 5. Disable sleep
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

## 6. GitHub and this repo
ssh-keygen -t ed25519 -C "tatedeb"
cat ~/.ssh/id_ed25519.pub #add to GitHub > Settings > SSH keys
ssh -T git@github.com
git config --global user.name "Tate Christensen"
git config --global user.email "<github email>"
sudo mkdir -p /srv/homelab
sudo chown $USER:$USER /srv/homelab
git clone git@github.com:<github-user>/homelab.git /srv/homelab

## 7. Network
- IP reservation 192.168.86.243 is tied to the Wi-Fi card's MAC in the Google Home app
- It survives a reinstall, so nothing to redo unless the Wi-Fi card changes

## 8. Verify
sudo reboot, then SSH in from the Mac without touching the PC

## To do
- Docker and Compose (official repo)
- Fix Docker's UFW bypass
- Tailscale
