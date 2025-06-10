#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Detect OS and set install commands
detect_os() {
    log_info "Detecting operating system..."
    check_sudo
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            OS="ubuntu"
            INSTALL_CMD="${SUDO_CMD} apt-get install -y"
            UPDATE_CMD="${SUDO_CMD} apt-get update"
            PACKAGES="git neovim tmux zsh curl tree htop fzf openssh-client"
        elif command -v pacman >/dev/null 2>&1; then
            OS="arch"
            INSTALL_CMD="${SUDO_CMD} pacman -S --noconfirm"
            UPDATE_CMD="${SUDO_CMD} pacman -Sy"
            PACKAGES="git neovim tmux zsh curl tree htop fzf openssh"
        elif command -v dnf >/dev/null 2>&1; then
            OS="fedora"
            INSTALL_CMD="${SUDO_CMD} dnf install -y"
            UPDATE_CMD="${SUDO_CMD} dnf check-update || true"
            PACKAGES="git neovim tmux zsh curl tree htop fzf openssh-clients"
        else
            log_error "Unsupported Linux distribution"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        if ! command -v brew >/dev/null 2>&1; then
            log_error "Homebrew not found. Install from https://brew.sh"
            exit 1
        fi
        INSTALL_CMD="brew install"
        UPDATE_CMD="brew update"
        PACKAGES="git neovim tmux zsh curl tree htop fzf openssh"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    log_success "Detected OS: $OS"
}

# Install packages
install_packages() {
    log_info "Installing packages..."
    $UPDATE_CMD
    $INSTALL_CMD $PACKAGES
    log_success "Package installation complete"
}

# Basic zsh setup
setup_zsh() {
    log_info "Setting up zsh..."
    
    cat > ~/.zshrc << 'EOF'
# Basic zsh config
export EDITOR=nvim
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# Basic aliases
alias ll='ls -la'
alias gs='git status' 
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias vim='nvim'

# Simple prompt
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# Enable completion
autoload -Uz compinit
compinit
EOF
    
    log_success "Zsh configuration complete"
}

# Basic tmux setup  
setup_tmux() {
    log_info "Setting up tmux..."
    
    cat > ~/.tmux.conf << 'EOF'
# Basic tmux config
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1

# Better splitting
bind | split-window -h
bind - split-window -v

# Vim navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-right '#(whoami)@#h %Y-%m-%d %H:%M'
EOF
    
    log_success "Tmux configuration complete"
}

# Set zsh as default shell
set_zsh_default() {
    if command -v zsh >/dev/null 2>&1 && [ "$SHELL" != "$(command -v zsh)" ]; then
        log_info "Setting zsh as default shell..."
        chsh -s "$(command -v zsh)" 2>/dev/null || log_warn "Could not change default shell"
    fi
}

# Main function
main() {
    log_info "Starting VM setup..."
    
    # Check if running interactively
    if [ -t 0 ]; then
        echo "Press Enter to continue or Ctrl+C to cancel..."
        read -r
    else
        log_info "Running automatically (piped mode)"
    fi
    
    detect_os
    install_packages
    setup_zsh
    setup_tmux
    set_zsh_default
    
    log_success "VM setup complete!"
    echo ""
    log_info "Next steps:"
    echo "  • Run 'zsh' to start using zsh"
    echo "  • Run 'tmux' to start terminal multiplexer" 
    echo "  • Use aliases: ll, gs, vim (→nvim), etc."
}

main "$@"
