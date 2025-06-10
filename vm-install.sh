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
        log_info "Running as root - sudo not needed"
    else
        SUDO_CMD="sudo"
        log_info "Running as regular user - will use sudo"
    fi
}

# Detect OS and set install commands
detect_os() {
    log_info "Detecting operating system..."
    
    check_sudo
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check for different Linux distributions
        if command -v apt-get >/dev/null 2>&1; then
            OS="ubuntu"
            INSTALL_CMD="${SUDO_CMD} apt-get install -y"
            UPDATE_CMD="${SUDO_CMD} apt-get update"
            # Only packages available in main Ubuntu repos
            PACKAGES="git vim curl"
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
        elif command -v yum >/dev/null 2>&1; then
            OS="centos"
            INSTALL_CMD="${SUDO_CMD} yum install -y"
            UPDATE_CMD="${SUDO_CMD} yum check-update || true"
            PACKAGES="git neovim tmux zsh curl tree htop fzf openssh-clients"
        else
            log_error "Unsupported Linux distribution"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        if ! command -v brew >/dev/null 2>&1; then
            log_error "Homebrew not found. Please install Homebrew first:"
            log_info "Visit: https://brew.sh"
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

# Install core packages
install_core_packages() {
    log_info "Installing core packages: $PACKAGES"
    
    # Update package manager
    log_info "Updating package manager..."
    $UPDATE_CMD
    
    # Install packages
    log_info "Installing packages..."
    $INSTALL_CMD $PACKAGES
    
    # Try to install additional packages that might be available
    if [ "$OS" = "ubuntu" ]; then
        log_info "Attempting to install additional packages..."
        ${SUDO_CMD} apt-get install -y tmux zsh tree htop fzf openssh-client 2>/dev/null || log_warn "Some packages not available in this Ubuntu environment"
    fi
    
    log_success "Core packages installation complete"
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."
    
    local failed=0
    local tools=("git" "nvim" "curl")
    local optional_tools=("tmux" "zsh" "tree" "htop" "fzf")
    
    # Check essential tools
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool - installed"
        else
            log_error "$tool - NOT FOUND"
            failed=1
        fi
    done
    
    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool - installed"
        else
            log_warn "$tool - not available (optional)"
        fi
    done
    
    if [ $failed -eq 1 ]; then
        log_error "Some essential tools failed to install"
        exit 1
    else
        log_success "All essential tools verified successfully"
    fi
}

# Setup minimal zinit and zsh config
setup_zsh_config() {
    log_info "Setting up minimal zinit and zsh configuration..."
    
    # Create .zshrc with minimal zinit setup
    cat > ~/.zshrc << 'EOF'
# Minimal VM zshrc with zinit
# Use C locale for containers, or en_US.UTF-8 if available
if locale -a 2>/dev/null | grep -q "en_US.utf8\|en_US.UTF-8"; then
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
else
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi
export EDITOR=nvim

# Zinit installation and setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Set up fzf key bindings and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# FZF configuration
if command -v fzf >/dev/null 2>&1; then
    # disable sort when completing `git checkout`
    zstyle ':completion:*:git-checkout:*' sort false
    # set descriptions format to enable group support
    # NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
    zstyle ':completion:*:descriptions' format '[%d]'
    # set list-colors to enable filename colorizing
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
    zstyle ':completion:*' menu no
    # preview directory's content with ls when completing cd
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'
    # custom fzf flags
    # NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
    zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
    # switch group using `<` and `>`
    zstyle ':fzf-tab:*' switch-group '<' '>'
fi
# END FZF

# Essential plugins only
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

# A bit extra
zinit load zdharma-continuum/history-search-multi-word
zinit light Aloxaf/fzf-tab
zinit light jeffreytse/zsh-vi-mode

# Bind fzf to Ctrl+R for fuzzy multi-word history search
if command -v fzf >/dev/null 2>&1; then
    __fzf_history_search() {
      local selected
      selected=$(fc -rl 1 | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*//' | sort -u | fzf --tac +s --query="$LBUFFER")
      if [[ -n $selected ]]; then
        BUFFER=$selected
        CURSOR=${#BUFFER}
        zle redisplay
      fi
    }
    zle -N __fzf_history_search
    bindkey '^R' __fzf_history_search
fi

# Vi mode
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
VI_MODE_SET_CURSOR=true

# Defaults
VI_MODE_CURSOR_NORMAL=2   # Block
VI_MODE_CURSOR_INSERT=5   # Blinking bar
VI_MODE_CURSOR_VISUAL=6
VI_MODE_CURSOR_OPPEND=0

ZVM_VI_INSERT_ESCAPE_BINDKEY=jj

# History settings
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Vi mode
bindkey -v
bindkey '^ ' autosuggest-accept     # Ctrl+Space
bindkey '^?' backward-delete-char

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias grep='grep --color=auto'
alias vim='nvim'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# Tmux shortcuts
alias t='tmux'
alias ta='tmux attach'
alias tn='tmux new-session'

# Directory navigation
alias dev='cd ~/dev'
alias tmp='cd /tmp'

# Basic prompt (simple and fast)
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b '
setopt PROMPT_SUBST
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %F{red}${vcs_info_msg_0_}%f$ '

# Completion
autoload -Uz compinit
compinit
EOF
    
    log_success "Zinit and zsh configuration complete"
}

# Setup minimal tmux config
setup_tmux_config() {
    log_info "Setting up minimal tmux configuration..."
    
    # Create .tmux.conf with essential settings
    cat > ~/.tmux.conf << 'EOF'
# Minimal VM tmux config
# Keep default Ctrl-b prefix
set -g prefix C-b

# Basic settings
set -g default-terminal "screen-256color"
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Faster key repetition
set -s escape-time 0
set -g repeat-time 600

# Better window splitting
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# Easy config reload
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Copy mode vi bindings
setw -g mode-keys vi
bind v copy-mode
bind p paste-buffer

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-interval 1
set -g status-left-length 30
set -g status-right-length 50

# Status bar content
set -g status-left '#[fg=green,bold][#S] '
set -g status-right '#[fg=yellow]#(whoami)@#h #[fg=cyan]%Y-%m-%d %H:%M'

# Window status
setw -g window-status-current-style 'fg=black bg=green bold'
setw -g window-status-current-format ' #I:#W '
setw -g window-status-style 'fg=white bg=black'
setw -g window-status-format ' #I:#W '

# Pane borders
set -g pane-border-style 'fg=brightblack'
set -g pane-active-border-style 'fg=green'

# Message style
set -g message-style 'fg=yellow bg=black bold'
EOF
    
    log_success "Tmux configuration complete"
}

# Set zsh as default shell
set_default_shell() {
    if [ "$SHELL" != "$(command -v zsh)" ]; then
        log_info "Setting zsh as default shell..."
        if command -v zsh >/dev/null 2>&1; then
            local zsh_path=$(command -v zsh)
            if [ "$EUID" -eq 0 ]; then
                # Running as root - change shell for root
                chsh -s "$zsh_path" root
            else
                chsh -s "$zsh_path"
            fi
            log_success "Default shell set to zsh (will take effect on next login)"
        else
            log_warn "zsh not found, keeping current shell"
        fi
    fi
}

# Display next steps
show_next_steps() {
    log_success "VM setup complete!"
    echo ""
    log_info "Tmux features added:"
    echo "  • Default Ctrl-b prefix (consistent with your setup)"
    echo "  • Mouse support enabled"
    echo "  • Vim-style pane navigation (h/j/k/l)"
    echo "  • Better window splitting (| and -)"
    echo "  • Config reload with Prefix+r"
    echo "  • Clean status bar with user@host and time"
    echo ""
    log_info "Installed tools:"
    echo "  git  - Version control"
    echo "  nvim - Text editor"
    echo "  tmux - Terminal multiplexer"
    echo "  zsh  - Advanced shell with zinit"
    echo "  curl - Download tool"
    echo "  tree - Directory viewer"
    echo "  htop - Process monitor"
    echo "  fzf  - Fuzzy finder"
    echo ""
    log_info "Zsh features added:"
    echo "  • Auto-suggestions (Ctrl+Space to accept)"
    echo "  • Syntax highlighting"
    echo "  • History search (Ctrl+R)"
    echo "  • Enhanced tab completion (fzf-tab)"
    echo "  • Vi mode with 'jj' escape"
    echo "  • Git branch in prompt"
    echo "  • Essential aliases (ll, gs, vim->nvim, etc.)"
    echo ""
    log_info "Next steps:"
    echo "  1. Run 'zsh' to switch to zsh immediately"
    echo "  2. Or log out and back in for permanent switch"
    echo "  3. Type 'gs' for git status, 't' for tmux, etc."
    echo ""
    log_warn "Note: Don't source ~/.zshrc from bash - start zsh first!"
}

# Main function
main() {
    log_info "Starting VM core installation..."
    echo "This will install essential CLI tools for VM environments."
    echo "Press Ctrl+C to cancel, or Enter to continue..."
    read -r
    
    detect_os
    install_core_packages
    verify_installations
    setup_zsh_config
    setup_tmux_config
    set_default_shell
    show_next_steps
}

# Run main function
main "$@"
