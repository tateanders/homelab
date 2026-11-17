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
- first, run
   ```bash
   sudo reboot
   ```
- then SSH in from the Mac without touching the PC


## 9. Install Docker
- Run the install docker script
   ```bash
   sudo /srv/homelab/scripts/install-docker.sh
   ```

## 10. Make Docker respect UFW
- Run the docker UFW script
   ```bash
   sudo /srv/homelab/scripts/docker-ufw.sh
   ```
- LAN block test. Start a test container on TateDeb:
   ```bash
   sudo docker run -d --rm --name ufwtest -p 8080:80 nginx:alpine
   ```
   From another device on the LAN (should time out):
   ```bash
   curl -m 5 http://192.168.86.243:8080
   ```
   Back on TateDeb, check that the drop was logged, then stop the container:
   ```bash
   sudo journalctl -k --since "5 min ago" | grep "UFW DOCKER BLOCK"
   sudo docker stop ufwtest
   ```
- Container internet test (should print the Example Domain HTML):
   ```bash
   sudo docker run --rm alpine wget -qO- -T 5 https://example.com
   ```
- Reboot, then check that the DOCKER-USER chain still has the rules and "1 references":
   ```bash
   sudo iptables -L DOCKER-USER -n -v
   ```
###Notes
- To expose a container: `sudo ufw route allow proto tcp from <source> to any port <container port>`. Use the container's internal port, not the published one.
- If ufw-docker ever needs an update, download it, review it again, then replace the copy in `scripts/vendor/`.

## To do
- Tailscale
