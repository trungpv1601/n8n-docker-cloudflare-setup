#!/bin/bash

# n8n Update Script
# Updates n8n Docker containers with backup and rollback capabilities

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="n8n-docker-caddy"
BACKUP_DIR="$SCRIPT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        echo "Usage: sudo ./update.sh [options]"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "n8n Update Script"
    echo
    echo "Usage: sudo ./update.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -b, --backup-only       Only create backup, don't update"
    echo "  -u, --update-only       Only update containers, don't backup"
    echo "  -r, --rollback [backup] Rollback to specific backup"
    echo "  --no-backup             Skip backup creation"
    echo "  --force                 Force update without confirmation"
    echo "  --dry-run               Show what would be done without executing"
    echo
    echo "Examples:"
    echo "  sudo ./update.sh                    # Full update with backup"
    echo "  sudo ./update.sh --backup-only     # Create backup only"
    echo "  sudo ./update.sh --no-backup       # Update without backup"
    echo "  sudo ./update.sh --rollback        # List available backups"
    echo "  sudo ./update.sh --rollback 20231201_120000  # Rollback to specific backup"
}

# Function to create backup
create_backup() {
    print_status "Creating backup..."

    mkdir -p "$BACKUP_DIR"
    BACKUP_PATH="$BACKUP_DIR/n8n_backup_$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    cd "$SCRIPT_DIR/$PROJECT_DIR" 2>/dev/null || {
        print_error "n8n project directory not found. Run install.sh first."
        exit 1
    }

    # Stop containers for consistent backup
    print_status "Stopping containers for backup..."
    docker compose down

    # Backup Docker volumes
    print_status "Backing up Docker volumes..."
    docker run --rm -v n8n_data:/source -v "$BACKUP_PATH":/backup alpine tar czf /backup/n8n_data.tar.gz -C /source .
    docker run --rm -v caddy_data:/source -v "$BACKUP_PATH":/backup alpine tar czf /backup/caddy_data.tar.gz -C /source .

    # Backup configuration files
    print_status "Backing up configuration files..."
    cp -r .env "$BACKUP_PATH/" 2>/dev/null || true
    cp -r caddy_config "$BACKUP_PATH/" 2>/dev/null || true
    cp -r docker-compose.yml "$BACKUP_PATH/" 2>/dev/null || true

    # Create backup info file
    cat > "$BACKUP_PATH/backup_info.txt" << EOF
Backup created: $(date)
n8n version: $(docker compose images n8n --format "{{.Image}}" 2>/dev/null || echo "unknown")
Caddy version: $(docker compose images caddy --format "{{.Image}}" 2>/dev/null || echo "unknown")
Docker version: $(docker --version)
EOF

    # Restart containers
    print_status "Restarting containers..."
    docker compose up -d

    print_success "Backup created: $BACKUP_PATH"
    echo "Backup contents:"
    ls -la "$BACKUP_PATH"
}

# Function to list available backups
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_warning "No backups found."
        return
    fi

    echo "Available backups:"
    for backup in "$BACKUP_DIR"/n8n_backup_*; do
        if [[ -d "$backup" ]]; then
            backup_name=$(basename "$backup")
            backup_date=$(echo "$backup_name" | sed 's/n8n_backup_//' | sed 's/_/ /')
            backup_date=$(date -d "${backup_date//_/:}" 2>/dev/null || echo "Invalid date")

            echo "  $backup_name ($backup_date)"
            if [[ -f "$backup/backup_info.txt" ]]; then
                grep "n8n version\|Caddy version" "$backup/backup_info.txt" | sed 's/^/    /'
            fi
        fi
    done
}

# Function to rollback to a specific backup
rollback() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/n8n_backup_$backup_name"

    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup not found: $backup_name"
        echo
        list_backups
        exit 1
    fi

    print_warning "This will restore n8n to the backup state: $backup_name"
    print_warning "Current data will be LOST!"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Rollback cancelled."
        exit 0
    fi

    cd "$SCRIPT_DIR/$PROJECT_DIR" 2>/dev/null || {
        print_error "n8n project directory not found."
        exit 1
    }

    # Stop containers
    print_status "Stopping containers..."
    docker compose down

    # Remove current volumes
    print_status "Removing current data..."
    docker volume rm n8n_data caddy_data 2>/dev/null || true

    # Recreate volumes
    print_status "Recreating volumes..."
    docker volume create n8n_data
    docker volume create caddy_data

    # Restore volumes
    print_status "Restoring data volumes..."
    docker run --rm -v n8n_data:/target -v "$backup_path":/backup alpine tar xzf /backup/n8n_data.tar.gz -C /target
    docker run --rm -v caddy_data:/target -v "$backup_path":/backup alpine tar xzf /backup/caddy_data.tar.gz -C /target

    # Restore configuration files
    print_status "Restoring configuration files..."
    cp "$backup_path/.env" . 2>/dev/null || true
    cp -r "$backup_path/caddy_config" . 2>/dev/null || true
    cp "$backup_path/docker-compose.yml" . 2>/dev/null || true

    # Start containers
    print_status "Starting containers..."
    docker compose up -d

    print_success "Rollback completed successfully!"
}

# Function to update containers
update_containers() {
    cd "$SCRIPT_DIR/$PROJECT_DIR" 2>/dev/null || {
        print_error "n8n project directory not found. Run install.sh first."
        exit 1
    }

    print_status "Checking for updates..."

    # Pull latest images
    print_status "Pulling latest images..."
    docker compose pull

    # Check if updates are available
    if docker compose images --format "{{.Image}}" | xargs -I {} docker image inspect {} --format '{{.RepoTags}} {{.Created}}' | grep -q "$(date +%Y)"; then
        print_status "Updates found. Updating containers..."
    else
        print_status "Checking for newer images..."
    fi

    # Stop and recreate containers with new images
    print_status "Recreating containers..."
    docker compose up -d --force-recreate

    # Wait for containers to be ready
    print_status "Waiting for containers to start..."
    sleep 10

    # Check container status
    if docker compose ps | grep -q "Up"; then
        print_success "Containers updated and running successfully!"

        # Show current versions
        echo
        echo "Current versions:"
        docker compose images --format "table {{.Service}}\t{{.Image}}\t{{.Tag}}"

        # Show running containers
        echo
        echo "Running containers:"
        docker compose ps

    else
        print_error "Some containers failed to start!"
        echo "Container status:"
        docker compose ps
        echo
        echo "Check logs with: docker compose logs"
        exit 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return
    fi

    print_status "Cleaning up old backups (keeping last 5)..."
    cd "$BACKUP_DIR"
    ls -1 -t n8n_backup_* | tail -n +6 | xargs -I {} rm -rf {} 2>/dev/null || true
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Compose first."
        exit 1
    fi

    # Check if in project directory or if project directory exists
    if [[ ! -d "$SCRIPT_DIR/$PROJECT_DIR" ]]; then
        print_error "n8n project directory not found. Please run install.sh first."
        exit 1
    fi

    print_success "System requirements check passed."
}

# Main script logic
main() {
    local backup_only=false
    local update_only=false
    local no_backup=false
    local force=false
    local dry_run=false
    local rollback_target=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--backup-only)
                backup_only=true
                shift
                ;;
            -u|--update-only)
                update_only=true
                shift
                ;;
            -r|--rollback)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    rollback_target="$2"
                    shift 2
                else
                    list_backups
                    exit 0
                fi
                ;;
            --no-backup)
                no_backup=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Handle dry run
    if [[ "$dry_run" == true ]]; then
        print_status "DRY RUN MODE - No changes will be made"
        echo
        echo "Would perform the following actions:"
        if [[ "$backup_only" == true ]]; then
            echo "- Create backup"
        elif [[ "$update_only" == true ]]; then
            echo "- Update containers (no backup)"
        elif [[ -n "$rollback_target" ]]; then
            echo "- Rollback to backup: $rollback_target"
        else
            echo "- Create backup (unless --no-backup specified)"
            echo "- Update containers"
        fi
        echo "- Cleanup old backups"
        exit 0
    fi

    # Check root permissions
    check_root

    # Check requirements
    check_requirements

    echo -e "${GREEN}n8n Update Script${NC}"
    echo "Timestamp: $(date)"
    echo

    # Handle rollback
    if [[ -n "$rollback_target" ]]; then
        rollback "$rollback_target"
        exit 0
    fi

    # Handle backup only
    if [[ "$backup_only" == true ]]; then
        create_backup
        cleanup_old_backups
        exit 0
    fi

    # Confirmation prompt (unless forced)
    if [[ "$force" != true ]]; then
        echo "This will update your n8n installation to the latest version."
        if [[ "$no_backup" != true && "$update_only" != true ]]; then
            echo "A backup will be created before updating."
        fi
        read -p "Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Update cancelled."
            exit 0
        fi
    fi

    # Create backup (unless disabled or update-only)
    if [[ "$no_backup" != true && "$update_only" != true ]]; then
        create_backup
        echo
    fi

    # Update containers
    update_containers

    # Cleanup old backups
    cleanup_old_backups

    echo
    print_success "Update completed successfully!"
    echo
    print_status "Your n8n instance should be available at the same URL as before."
    print_status "Check logs with: cd $PROJECT_DIR && docker compose logs -f"
}

# Run main function with all arguments
main "$@"
