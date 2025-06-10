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
            setup_script_found=false
            
            if [ -f install.sh ]; then
                setup_script_found=true
                echo ""
                log_info "Found install.sh in dotfiles."
                echo "Run the installation script? (y/n) [n]:"
                read -r run_install
                if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
                    log_info "Running ./install.sh..."
                    bash install.sh
                    log_success "Installation script completed!"
                fi
            elif [ -f setup.sh ]; then
                setup_script_found=true
                echo ""
                log_info "Found setup.sh in dotfiles."
                echo "Run the setup script? (y/n) [n]:"
                read -r run_setup
                if [ "$run_setup" = "y" ] || [ "$run_setup" = "Y" ]; then
                    log_info "Running ./setup.sh..."
                    bash setup.sh
                    log_success "Setup script completed!"
                fi
            elif [ -f Makefile ]; then
                setup_script_found=true
                echo ""
                log_info "Found Makefile in dotfiles."
                echo "Run 'make install'? (y/n) [n]:"
                read -r run_make
                if [ "$run_make" = "y" ] || [ "$run_make" = "Y" ]; then
                    log_info "Running make install..."
                    make install
                    log_success "Make install completed!"
                fi
            fi
            
            if [ "$setup_script_found" = false ]; then
                log_info "No standard setup script found (install.sh, setup.sh, Makefile)"
                log_info "You can manually run your dotfiles setup from $clone_dir"
            fi
            
        else
            log_error "Failed to clone dotfiles repository."
            log_error "Please check:"
            log_error "  - Repository name: $github_username/$repo_name"
            log_error "  - Deploy key was added correctly"
            log_error "  - Repository exists and is accessible"
            echo ""
            show_usage_examples "$github_username" "$repo_name"
            exit 1
        fi
    else
        log_error "Deploy key connection failed."
        echo ""
        log_info "Troubleshooting steps:"
        echo "  1. Verify the deploy key was added to your GitHub repository"
        echo "  2. Make sure you copied the entire key (including ssh-ed25519 prefix)"
        echo "  3. Check that the repository exists and is accessible"
        echo "  4. Test manually with: ssh -T github-dotfiles"
        echo ""
        show_usage_examples "YOUR_USERNAME" "dotfiles"
        exit 1
    fi
    
    # Show final status
    echo ""
    log_success "Dotfiles setup complete!"
    echo ""
    log_info "Deploy key details:"
    echo "  • Key file: ~/.ssh/dotfiles_deploy_key"
    echo "  • SSH alias: github-dotfiles"
    echo "  • Access: Read-only to your dotfiles repository"
    echo ""
    log_info "To remove access later:"
    echo "  • Go to your repo Settings → Deploy keys → Delete the key"
    echo "  • Or run: rm ~/.ssh/dotfiles_deploy_key*"
}

# Show usage examples
show_usage_examples() {
    local username=$1
    local repo=$2
    
    echo ""
    log_info "Manual usage examples:"
    echo ""
    echo "Clone repository:"
    echo "  git clone github-dotfiles:$username/$repo.git ~/dotfiles"
    echo ""
    echo "Test SSH connection:"
    echo "  ssh -T github-dotfiles"
    echo ""
    echo "Pull updates (from within repo):"
    echo "  git pull origin main"
}

# Main function
main() {
    echo "=============================================================================="
    echo "                        Dotfiles Deploy Key Setup"
    echo "=============================================================================="
    echo ""
    log_info "This script will:"
    echo "  • Generate a dedicated SSH deploy key for your dotfiles repository"
    echo "  • Configure SSH to use this key for GitHub access"
    echo "  • Help you add the key to your GitHub repository"
    echo "  • Clone your dotfiles repository (optional)"
    echo ""
    echo "Deploy keys provide:"
    echo "  ✓ Read-only access (secure)"
    echo "  ✓ Repository-specific access"
    echo "  ✓ Easy to revoke from GitHub"
    echo ""
    echo "Press Ctrl+C to cancel, or Enter to continue..."
    read -r
    
    setup_deploy_key_for_dotfiles
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Dotfiles Deploy Key Setup"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "This script sets up a secure SSH deploy key for accessing your private"
    echo "dotfiles repository on GitHub. Deploy keys provide read-only, repository-"
    echo "specific access that can be easily managed and revoked."
    echo ""
    echo "The script will:"
    echo "  1. Generate an SSH key dedicated to dotfiles access"
    echo "  2. Configure SSH with a github-dotfiles alias"
    echo "  3. Guide you through adding the key to GitHub"
    echo "  4. Test the connection"
    echo "  5. Optionally clone your dotfiles repository"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    exit 0
fi

# Run main function
main "$@"
