# VM Bootstrap

Quick setup scripts for new VMs and containers. These scripts provide a modern development environment with essential tools and secure access to private dotfiles.

## 🚀 Quick Start

### One-liner VM Setup
```bash
# Install essential dev tools + modern shell setup
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/vm-install.sh | bash
```

### One-liner SSH Setup for Dotfiles
```bash
# Set up secure SSH deploy key for private dotfiles access
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/setup-dotfiles-ssh.sh | bash
```

### Complete Workflow
```bash
# 1. Set up VM with essential tools
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/vm-install.sh | bash

# 2. Set up SSH access to private dotfiles
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/setup-dotfiles-ssh.sh | bash

# 3. Your dotfiles are now cloned and ready to use!
```

## 📦 What Gets Installed

### vm-install.sh
**Essential development tools:**
- **git** - Version control
- **neovim** - Modern text editor  
- **tmux** - Terminal multiplexer
- **zsh** - Advanced shell
- **fzf** - Fuzzy finder
- **tree** - Directory viewer
- **htop** - Process monitor
- **curl** - Download tool

**Modern shell setup:**
- **Zinit** - Fast zsh plugin manager
- **Auto-suggestions** - Command completion
- **Syntax highlighting** - Real-time command validation
- **History search** - Fuzzy history with Ctrl+R
- **Vi mode** - Vim keybindings with 'jj' escape
- **fzf integration** - Enhanced tab completion
- **Git branch prompt** - Shows current branch
- **Essential aliases** - ll, gs, ga, gc, etc.

**Tmux configuration:**
- **Vim-style navigation** - h/j/k/l pane movement
- **Mouse support** - Click to select panes
- **Better splitting** - | and - for splits
- **Clean status bar** - Shows user@host and time
- **Quick reload** - Prefix+r to reload config

### setup-dotfiles-ssh.sh
**Secure dotfiles access:**
- **Deploy key generation** - Repository-specific SSH key
- **Read-only access** - Cannot push changes (secure)
- **GitHub integration** - Guided setup process
- **Auto-clone** - Downloads your private dotfiles
- **Setup detection** - Finds and runs install.sh/setup.sh/Makefile

## 🔒 Security Features

### Deploy Keys vs Personal SSH Keys
- **Repository-specific** - Only works for your dotfiles repo
- **Read-only by default** - Cannot push changes
- **Easy to revoke** - Remove from GitHub repo settings
- **VM-friendly** - Safe for temporary environments

### No Sensitive Information
- No API keys, passwords, or secrets
- No personal paths or usernames  
- No company-specific configurations
- Safe to use on shared or temporary VMs

## 🖥️ Supported Platforms

- **Arch Linux** - Full package support
- **Ubuntu/Debian** - Core packages + additional installs
- **Fedora/CentOS** - Full package support  
- **macOS** - Via Homebrew

## 📋 Requirements

- **Linux/macOS** with internet access
- **Package manager** - pacman, apt, dnf, or brew
- **Basic permissions** - sudo access or root (auto-detected)

## 🛠️ Manual Usage

### Download and Run Locally
```bash
# Download scripts
wget https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/vm-install.sh
wget https://raw.githubusercontent.com/YOUR_USERNAME/vm-bootstrap/main/setup-dotfiles-ssh.sh

# Make executable
chmod +x vm-install.sh setup-dotfiles-ssh.sh

# Run VM setup
./vm-install.sh

# Run SSH setup (after VM setup)
./setup-dotfiles-ssh.sh
```

### SSH Deploy Key Management
```bash
# Test SSH connection
ssh -T github-dotfiles

# Clone dotfiles manually  
git clone github-dotfiles:YOUR_USERNAME/dotfiles.git ~/dotfiles

# Remove deploy key when done
# Go to: https://github.com/YOUR_USERNAME/dotfiles/settings/keys
```

## 🔧 Customization

These scripts provide a solid foundation that works well for most developers. For personalized configurations:

1. **Run the bootstrap** - Get the essentials working
2. **Clone your dotfiles** - Use the SSH setup to access private configs  
3. **Run your install script** - Apply your personal configurations

## 🐛 Troubleshooting

### VM Install Issues
- **Package not found**: Some minimal containers may need additional repos
- **Permission denied**: Ensure you have sudo access or are running as root
- **Locale warnings**: Script handles this automatically with fallbacks

### SSH Setup Issues  
- **ssh-keygen not found**: Script auto-installs SSH tools
- **Connection failed**: Verify deploy key was added to GitHub correctly
- **Clone failed**: Check repository name and GitHub access

### Getting Help
```bash
# Check what was installed
which git nvim tmux zsh fzf

# Test zsh setup
zsh

# Test tmux setup  
tmux

# Test SSH setup
ssh -T github-dotfiles
```

## 📝 What's Next?

After running these scripts:

1. **Switch to zsh**: Run `zsh` or log out/in
2. **Start tmux**: Run `tmux` for terminal multiplexing
3. **Use your dotfiles**: Your personal configs are now available
4. **Customize further**: Add any VM-specific configurations

## 🤝 Contributing

Found an issue or have a suggestion? Feel free to open an issue or submit a pull request!

---

**Note**: These are the public bootstrap scripts. Full dotfiles and personal configurations are kept in a separate private repository.
