#!/bin/bash
set -e

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing required packages..."
sudo apt install -y git curl nginx build-essential

# ─── NODE VIA NVM ────────────────────────────────────────────────────────────

echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

echo "Loading NVM..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Installing Node (one version behind latest LTS)..."
# Get the second-to-last LTS version (e.g., 20.x if 22.x is latest)
LATEST_LTS=$(nvm ls-remote --lts | tail -1 | awk '{print $1}')
PREV_LTS=$(nvm ls-remote --lts | grep -v "${LATEST_LTS%%.*}\." | tail -1 | awk '{print $1}')
echo "Latest LTS: $LATEST_LTS — Installing previous LTS: $PREV_LTS"
nvm install "$PREV_LTS"
nvm use "$PREV_LTS"
nvm alias default "$PREV_LTS"

echo "Installing PM2..."
npm install -g pm2

# ─── DOCKER ──────────────────────────────────────────────────────────────────

echo "Installing Docker..."
sudo apt install -y ca-certificates gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
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

# ─── POSTGRESQL ──────────────────────────────────────────────────────────────

echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Interactive DB setup
echo ""
echo "─────────────────────────────────────────────"
echo "        PostgreSQL Interactive Setup"
echo "─────────────────────────────────────────────"

read -rp "Enter DB username to create: " DB_USER

while true; do
  read -rsp "Enter password for '${DB_USER}': " DB_PASS
  echo ""
  read -rsp "Confirm password: " DB_PASS_CONFIRM
  echo ""
  if [ "$DB_PASS" = "$DB_PASS_CONFIRM" ]; then
    break
  else
    echo "Passwords do not match. Try again."
  fi
done

read -rp "Enter database name to create: " DB_NAME

echo "Creating PostgreSQL user and database..."

# Create user if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -c "ALTER USER \"${DB_USER}\" CREATEDB;"

# Create database if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"

echo "PostgreSQL setup complete — user '${DB_USER}' and database '${DB_NAME}' are ready."

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
echo "PM2:     $(pm2 --version)"
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
echo "4. Run:  pm2 startup   → copy and run the output command"
echo "5. Run:  pm2 save"