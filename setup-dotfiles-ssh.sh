#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we need sudo
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

# Function to setup deploy key for dotfiles
setup_deploy_key_for_dotfiles() {
    log_info "Setting up deploy key for secure dotfiles access..."
    
    # Create SSH directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Check if deploy key already exists
    if [ -f ~/.ssh/dotfiles_deploy_key ]; then
        log_warn "Deploy key already exists at ~/.ssh/dotfiles_deploy_key"
        echo "Do you want to:"
        echo "1. Use existing key"
        echo "2. Generate new key (will overwrite)"
        echo "3. Exit"
        read -r choice
        case $choice in
            1) log_info "Using existing deploy key..." ;;
            2) 
                log_info "Generating new deploy key..."
                rm -f ~/.ssh/dotfiles_deploy_key ~/.ssh/dotfiles_deploy_key.pub
                ;;
            3) exit 0 ;;
            *) log_error "Invalid choice. Exiting."; exit 1 ;;
        esac
    fi
    
    # Generate dedicated deploy key if it doesn't exist
    if [ ! -f ~/.ssh/dotfiles_deploy_key ]; then
        log_info "Generating dedicated deploy key for dotfiles..."
        
        # Check for required tools
        if ! command -v ssh-keygen >/dev/null 2>&1; then
            log_error "ssh-keygen not found. Installing SSH tools..."
            
            # Check sudo requirements
            check_sudo
            
            if command -v pacman >/dev/null 2>&1; then
                ${SUDO_CMD} pacman -S --noconfirm openssh
            elif command -v apt-get >/dev/null 2>&1; then
                ${SUDO_CMD} apt-get update && ${SUDO_CMD} apt-get install -y openssh-client
            elif command -v dnf >/dev/null 2>&1; then
                ${SUDO_CMD} dnf install -y openssh-clients
            else
                log_error "Cannot install SSH tools automatically. Please install openssh/ssh-client package."
                exit 1
            fi
        fi
        
        # Get hostname (fallback if hostname command not available)
        if command -v hostname >/dev/null 2>&1; then
            host_name=$(hostname)
        else
            host_name=$(cat /etc/hostname 2>/dev/null || echo "vm")
        fi
        
        ssh-keygen -t ed25519 -C "dotfiles-deploy-${host_name}-$(date +%Y%m%d)" -f ~/.ssh/dotfiles_deploy_key -N ""
        
        # Set proper permissions
        chmod 600 ~/.ssh/dotfiles_deploy_key
        chmod 644 ~/.ssh/dotfiles_deploy_key.pub
        
        log_success "Deploy key generated!"
    fi
    
    # Create or update SSH config entry for dotfiles
    log_info "Configuring SSH for deploy key..."
    
    # Remove existing github-dotfiles entry if it exists
    if [ -f ~/.ssh/config ]; then
        # Create backup
        cp ~/.ssh/config ~/.ssh/config.backup
        # Remove existing github-dotfiles section
        sed -i '/^# Dotfiles deploy key configuration$/,/^$/d' ~/.ssh/config 2>/dev/null || true
        sed -i '/^Host github-dotfiles$/,/^$/d' ~/.ssh/config 2>/dev/null || true
    fi
    
    # Add new SSH config entry
    cat >> ~/.ssh/config << 'EOF'

# Dotfiles deploy key configuration
Host github-dotfiles
    HostName github.com
    User git
    IdentityFile ~/.ssh/dotfiles_deploy_key
    IdentitiesOnly yes
EOF
    
    chmod 644 ~/.ssh/config
    
    # Display deploy key for GitHub
    echo ""
    echo "=============================================================================="
    log_success "Deploy key ready! Add this as a Deploy Key to your dotfiles repository:"
    echo "=============================================================================="
    echo ""
    cat ~/.ssh/dotfiles_deploy_key.pub
    echo ""
    echo "=============================================================================="
    echo ""
    log_info "Steps to add deploy key to GitHub:"
    echo ""
    echo "  1. Copy the key above (triple-click to select all)"
    echo "  2. Go to your dotfiles repository on GitHub"
    echo "  3. Click: Settings → Deploy keys → Add deploy key"
    echo "  4. Title: 'VM Deploy Key - $(cat /etc/hostname 2>/dev/null || echo "vm") - $(date +%Y-%m-%d)'"
    echo "  5. Paste the key in the 'Key' field"
    echo "  6. IMPORTANT: Leave 'Allow write access' UNCHECKED (read-only)"
    echo "  7. Click 'Add key'"
    echo ""
    echo "=============================================================================="
    echo ""
    echo "Press Enter when you've added the deploy key to continue..."
    read -r
    
    # Test connection using the deploy key
    log_info "Testing deploy key connection to GitHub..."
    
    # Test with timeout to avoid hanging
    if timeout 10 ssh -T github-dotfiles 2>&1 | grep -q "successfully authenticated"; then
        log_success "Deploy key connection successful!"
        
        # Get dotfiles repo info
        echo ""
        echo "Enter your GitHub username:"
        read -r github_username
        
        if [ -z "$github_username" ]; then
            log_error "Username cannot be empty"
            exit 1
        fi
        
        echo "Enter your dotfiles repository name [dotfiles]:"
        read -r repo_name
        repo_name=${repo_name:-dotfiles}
        
        # Ask about destination directory
        echo "Clone to which directory? [~/dotfiles]:"
        read -r clone_dir
        clone_dir=${clone_dir:-~/dotfiles}
        
        # Expand tilde
        clone_dir=$(eval echo "$clone_dir")
        
        # Check if directory exists
        if [ -d "$clone_dir" ]; then
            log_warn "Directory $clone_dir already exists"
            echo "Do you want to:"
            echo "1. Remove and re-clone"
            echo "2. Skip cloning"
            echo "3. Clone to different location"
            read -r dir_choice
            case $dir_choice in
                1) 
                    log_info "Removing existing directory..."
                    rm -rf "$clone_dir"
                    ;;
                2) 
                    log_info "Skipping clone. Deploy key is ready for manual use."
                    show_usage_examples "$github_username" "$repo_name"
                    return 0
                    ;;
                3)
                    echo "Enter new directory path:"
                    read -r clone_dir
                    clone_dir=$(eval echo "$clone_dir")
                    ;;
                *) 
                    log_error "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
        fi
        
        # Clone using deploy key
        log_info "Cloning $github_username/$repo_name to $clone_dir..."
        if git clone github-dotfiles:${github_username}/${repo_name}.git "$clone_dir"; then
            log_success "Dotfiles cloned successfully to $clone_dir!"
            
            # Check for common setup scripts
            cd "$clone_dir"
            setup
