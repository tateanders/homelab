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
- Reserved xxx.xxx.xx.243 in Google Home app
- Masked all sleep and suspend targets so the pc can't go to sleep
- Verified networking and SSH come up on their own by rebooting and sshing in via macbook

## 2026-11-13 Docker + UFW fix

### Docker Engine and Compose
- Installed from Docker's official apt repo
- Signing key: /etc/apt/keyrings/docker.asc
- Repo file: /etc/apt/sources.list.d/docker.sources (deb822 format)
- Packages: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
- Versions: Docker Engine 29.9.3, Compose v5.7.1
- Tested with hello-world. docker and containerd are both enabled at boot.
- Decision: I didn't add my user to the docker group. Given that group is basically root, so I use sudo for docker commands.

### Making Docker respect UFW
- Docker writes its own firewall rules, so published container ports skip UFW and are open to the whole LAN.
- Backed up /etc/ufw/after.rules and after6.rules to .bak before changing anything
- Downloaded the ufw-docker script (github.com/chaifeng/ufw-docker), reviewed it (no network calls besides man page links), and installed it to /usr/local/bin/ufw-docker
- Ran 'sudo ufw-docker install --docker-subnets 172.16.0.0/12'
  - The default install trusts 192.168.0.0/16, which includes my home LAN. Limiting it to Docker's subnet range means LAN devices get filtered.
  - 172.16.0.0/12 covers the networks Docker creates later (like compose networks), so I don't need to rerun install for each new stack.
- Restarted UFW with sudo systemctl restart ufw

### Testing
- Ran a test nginx container on port 8080. curl from my Mac timed out.
- Saw the drops in the kernel log: sudo journalctl -k | grep "UFW DOCKER BLOCK"
- A container can still reach the internet (wget to example.com worked)
- Rebooted and checked that the DOCKER-USER rules came back: sudo iptables -L DOCKER-USER -n -v

### Notes for later
- To expose a container: ufw route allow proto tcp from <source> to any port <container port>
  - Use the container's internal port, not the published host port
- IPv6 is off in Docker, so ufw-docker skipped the IPv6 rules


