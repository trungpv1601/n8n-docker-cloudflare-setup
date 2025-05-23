# Register your account on DigitalOcean

[![DigitalOcean Referral Badge](https://web-platforms.sfo2.cdn.digitaloceanspaces.com/WWW/Badge%201.svg)](https://www.digitalocean.com/?refcode=e0496d81b971&utm_campaign=Referral_Invite&utm_medium=Referral_Program&utm_source=badge)

# n8n Docker Setup with Caddy and Cloudflare SSL

A complete guide to set up n8n with Docker, Caddy reverse proxy, and Cloudflare SSL certificates on Ubuntu.

## 🚀 Installation Guide

### Step 1: Prepare Your Server

#### Create a dedicated user (recommended for security)
```bash
# Connect to your server as root
sudo adduser n8n-admin
sudo usermod -aG sudo n8n-admin
```

#### Switch to the new user
```bash
su - n8n-admin
```

### Step 2: Prepare SSL Certificates (Cloudflare)

Before installation, you need SSL certificates from Cloudflare:

1. **Log into Cloudflare Dashboard**
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
   - Select your domain

2. **Configure SSL/TLS Encryption Mode**
   - Navigate to `SSL/TLS` → `Overview`
   - Set encryption mode to `Full (strict)`
   - This ensures end-to-end encryption between Cloudflare and your origin server

3. **Generate Origin Certificate**
   - Navigate to `SSL/TLS` → `Origin Server`
   - Click `Create Certificate`
   - Click `Create`

4. **Save Certificate Files**
   - Copy the **Certificate** content (keep this ready)
   - Copy the **Private Key** content (keep this ready)
   - You'll need these during installation

### Step 3: Configure DNS (Cloudflare)

Set up DNS records for your n8n subdomain:

1. **In Cloudflare Dashboard**
   - Go to `DNS` → `Records`
   - Add a new `A` record:
     - **Name**: `n8n` (or your preferred subdomain)
     - **IPv4 address**: Your server's public IP
     - **Proxy status**: 🟠 Proxied (recommended)
   - Click `Save`

### Step 4: Download and Prepare Installation Script

```bash
# Download the installation files
git clone https://github.com/trungpv1601/n8n-docker-cloudflare-setup
cd n8n-docker-cloudflare-setup

# Make the install script executable
chmod +x install.sh
chmod +x update.sh
```

### Step 5: Run Installation

**Important**: Have your SSL certificate and private key ready before running the script.

```bash
# Run the installation script
sudo ./install.sh
```

During installation, you'll be prompted for:
- **Domain name**: `yourdomain.com`
- **Subdomain**: `n8n` (or your choice)
- **SSL Certificate**: Paste the certificate from Cloudflare
- **Private Key**: Paste the private key from Cloudflare

### Step 6: Access n8n
   - Open your browser
   - Navigate to `https://n8n.yourdomain.com`
   - Complete the initial n8n setup

## 🔄 Updating n8n

The setup includes an automated update script that handles backing up your data, updating containers, and provides rollback capabilities.

### Update Commands

#### Full Update (Recommended)
Creates a backup and updates to the latest version:
```bash
sudo ./update.sh
```

#### Quick Updates
```bash
# Update without creating a backup
sudo ./update.sh --no-backup

# Force update without confirmation prompt
sudo ./update.sh --force

# See what would be updated without making changes
sudo ./update.sh --dry-run
```

#### Backup Management
```bash
# Create backup only (no update)
sudo ./update.sh --backup-only

# Update containers only (no backup)
sudo ./update.sh --update-only
```

#### Rollback and Recovery
```bash
# List all available backups
sudo ./update.sh --rollback

# Rollback to a specific backup
sudo ./update.sh --rollback 20231201_120000

# Get help and see all options
sudo ./update.sh --help
```

### Update Process

When you run a full update, the script will:

1. **Create Backup**: Automatically backup your n8n data and configuration
2. **Pull Latest Images**: Download the newest n8n and Caddy Docker images
3. **Update Containers**: Recreate containers with new images
4. **Verify Status**: Check that everything is running correctly
5. **Cleanup**: Remove old backups (keeps last 5)

### Backup Location

Backups are stored in `./backups/` directory and include:
- n8n workflow data and settings
- Caddy configuration and certificates
- Environment variables and Docker configuration
- Backup metadata with version information

---

**⚠️ Important**: Keep your SSL private key secure and never share it publicly!
