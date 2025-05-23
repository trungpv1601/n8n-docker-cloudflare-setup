#!/bin/bash

# Simple n8n Setup Script - Ubuntu Only
# Based on https://github.com/n8n-io/n8n-docker-caddy

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/n8n-io/n8n-docker-caddy.git"
PROJECT_DIR="n8n-docker-caddy"

echo -e "${GREEN}n8n Setup Script - Ubuntu Installer${NC}"
echo "Using official repository: $REPO_URL"
echo

# Check root permissions
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Run with sudo${NC}"
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Check if running on Ubuntu/Debian
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Error: This script only supports Ubuntu/Debian systems${NC}"
    echo "apt-get package manager not found"
    exit 1
fi

echo "Installing prerequisites for Ubuntu..."

# Update package list
echo "Updating package list..."
apt-get update -qq

# Install git and curl
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get install -y git curl ca-certificates gnupg lsb-release -qq
fi

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."

    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin -qq

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    echo -e "${GREEN}Docker installed successfully${NC}"
else
    echo "Docker is already installed"
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get install -y docker-compose-plugin -qq 2>/dev/null || {
        # Fallback to standalone installation
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
    echo -e "${GREEN}Docker Compose installed successfully${NC}"
else
    echo "Docker Compose is already installed"
fi

# Verify installations
echo "Verifying installations..."
docker --version || {
    echo -e "${RED}Docker installation failed${NC}"
    exit 1
}

(docker compose version || docker-compose --version) || {
    echo -e "${RED}Docker Compose installation failed${NC}"
    exit 1
}

echo -e "${GREEN}All prerequisites installed successfully!${NC}"

# Clone repository
echo "Cloning n8n repository..."
if [[ -d "$PROJECT_DIR" ]]; then
    rm -rf "$PROJECT_DIR"
fi
git clone "$REPO_URL" "$PROJECT_DIR" -q
cd "$PROJECT_DIR"

# Create Docker volumes (as per official docs)
echo "Creating Docker volumes..."
docker volume create caddy_data &>/dev/null || true
docker volume create n8n_data &>/dev/null || true

# Open firewall ports (as per official docs)
echo "Opening firewall ports..."
if command -v ufw &> /dev/null; then
    ufw allow 80 &>/dev/null || true
    ufw allow 443 &>/dev/null || true
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http &>/dev/null || true
    firewall-cmd --permanent --add-service=https &>/dev/null || true
    firewall-cmd --reload &>/dev/null || true
fi

# Get domain configuration
echo
echo -e "${BLUE}Domain Configuration${NC}"
read -p "Enter your domain (e.g., example.com): " DOMAIN_NAME
read -p "Enter subdomain for n8n (e.g., n8n): " SUBDOMAIN

# Validate basic format
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+$ ]] || [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}Invalid domain format${NC}"
    exit 1
fi

echo
echo "n8n will be available at: https://${SUBDOMAIN}.${DOMAIN_NAME}"
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Get SSL certificates
echo
echo -e "${BLUE}SSL Certificate Setup${NC}"
echo "Paste your SSL certificate (Ctrl+D when done):"
SSL_CERT=$(cat)

echo
echo "Paste your SSL private key (Ctrl+D when done):"
SSL_KEY=$(cat)

# Basic validation
if [[ ! "$SSL_CERT" =~ "BEGIN CERTIFICATE" ]] || [[ ! "$SSL_KEY" =~ "BEGIN" ]]; then
    echo -e "${RED}Invalid SSL certificate or key format${NC}"
    exit 1
fi

# Configure environment
echo
echo "Configuring environment..."
cat > .env << EOF
DOMAIN_NAME=${DOMAIN_NAME}
SUBDOMAIN=${SUBDOMAIN}
GENERIC_TIMEZONE=UTC
DATA_FOLDER=$(pwd)
EOF

# Setup SSL
mkdir -p caddy_config/ssl
echo "$SSL_CERT" > caddy_config/ssl/cert.pem
echo "$SSL_KEY" > caddy_config/ssl/key.key
chmod 600 caddy_config/ssl/*

# Configure Caddy
cat > caddy_config/Caddyfile << EOF
${SUBDOMAIN}.${DOMAIN_NAME} {
    tls /config/ssl/cert.pem /config/ssl/key.key
    reverse_proxy n8n:5678 {
        flush_interval -1
    }
    header {
        Strict-Transport-Security max-age=31536000;
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }
}
EOF

# Start services (using official docker compose format)
echo "Starting n8n..."
docker compose up -d

# Wait for startup
sleep 5
if docker compose ps | grep -q "Up"; then
    echo
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo "n8n is running at: https://${SUBDOMAIN}.${DOMAIN_NAME}"
    echo
    echo "Commands:"
    echo "  docker compose logs -f    # View logs"
    echo "  docker compose down       # Stop"
    echo "  docker compose up -d      # Start"
    echo "  docker compose pull && docker compose up -d  # Update"
else
    echo -e "${RED}Failed to start services${NC}"
    echo "Check logs: docker compose logs"
    exit 1
fi
