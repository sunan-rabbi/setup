#!/bin/bash
set -e

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing required packages..."
sudo apt install -y git curl nginx build-essential

# ─── NODE VIA NVM ────────────────────────────────────────────────────────────

echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

echo "Loading NVM..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"


# ─── DOCKER ──────────────────────────────────────────────────────────────────

echo "Installing Docker..."
sudo apt install -y ca-certificates gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg


echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group so you don't need sudo
sudo usermod -aG docker "$USER"
echo "Docker installed. NOTE: Log out and back in for docker group to take effect."

# ─── SSH KEY ─────────────────────────────────────────────────────────────────

echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "github-actions-key" -f ~/.ssh/id_ed25519 -N ""

echo "Setting SSH permissions..."
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "Adding public key to authorized_keys..."
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys

# ─── SUMMARY ─────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════"
echo "              Install Summary"
echo "════════════════════════════════════════════"
echo "Node:    $(node -v)"
echo "npm:     $(npm -v)"
echo "Docker:  $(docker --version)"
echo "Postgres: $(psql --version)"
echo ""
echo "Your SSH private key (add to GitHub Actions secrets):"
cat ~/.ssh/id_ed25519

echo ""
echo "════════════════════════════════════════════"
echo "              Next Steps"
echo "════════════════════════════════════════════"
echo "1. Run:  source ~/.bashrc"
echo "2. Run:  newgrp docker                 (apply docker group)"
echo "3. Run:  docker ps                     (verify docker works)"