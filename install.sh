#!/usr/bin/env bash
# Bootstrap for Nix + nix-darwin

# Fail if run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "This script should NOT be run with sudo. Please run as your normal user."
    exit 1
fi

# Fail if no TTY (interactive only)
if [ ! -t 0 ]; then
    echo "No TTY detected. This bootstrap requires interactive input."
    exit 1
fi

# Abort if Command Line Tools install is already running
if pgrep -f "Install Command Line Developer Tools" >/dev/null; then
    echo "An Xcode Command Line Tools installation is already in progress."
    echo "Please complete or cancel it before running this bootstrap."
    exit 1
fi

set -euo pipefail

# Force the script to start in the user's home directory
cd "$HOME"

PRIVATE_REPO="github:optevo/nix"      # Private repo
CONFIG_DIR="${HOME}/config"          # Local Nix configuration
REPO_URL="https://github.com/optevo/nix.git"

echo "=== Starting real Nix bootstrap ==="
echo "Config directory: $CONFIG_DIR"

# Install Apple Developer Tools if needed
echo "Checking Apple Developer Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Apple Developer Tools..."
    xcode-select --install
else
    echo "Apple Developer Tools already installed."
fi

# Install Nix if missing
echo "Checking Nix..."

# Install if missing
if ! command -v nix >/dev/null 2>&1; then
    echo "Nix not found — installing..."
    sh <(curl -L https://nixos.org/nix/install) --daemon
fi

# Load vanilla Nix environment (multi-user install)
NIX_PROFILE="$HOME/.nix-profile/etc/profile.d/nix.sh"
if [ -r "$NIX_PROFILE" ]; then
    echo "Loading Nix environment..."
    . "$NIX_PROFILE"
fi

# Final sanity check
if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Nix is installed but not available in this shell."
    echo "Please restart your terminal and re-run the script."
    exit 1
fi

# Sync private configuration repository
echo "Syncing private configuration repository..."

# Tell Git to use the macOS Keychain (saves the token for future runs)
git config --global credential.helper osxkeychain

if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Repository exists. Updating..."
    cd "$CONFIG_DIR"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Warning: local changes detected in $CONFIG_DIR!"
        git status

        read -p "Do you want to discard these changes and reset to the latest origin/main? [y/N]: " yn
        case "$yn" in
            [Yy]* )
                echo "Fetching latest from origin..."
                git fetch origin
                echo "Resetting local changes..."
                git reset --hard origin/main
                ;;
            * )
                echo "Aborting bootstrap."
                exit 1
                ;;
        esac
    else
        echo "No local changes. Fetching latest from origin and resetting..."
        git fetch origin
        git reset --hard origin/main
    fi
else
    echo "First-time setup detected."
    echo "-----------------------------------------------------------"
    echo "You need a GitHub Personal Access Token (PAT) for this private repo."
    echo "1. When the browser opens, generate a token with 'repo' permissions."
    echo "2. Copy the token."
    echo "3. Come back here. Git will ask for your Username and Password."
    echo "4. PASTE THE TOKEN as your Password."
    echo "-----------------------------------------------------------"
    
    read -p "Press Enter to open GitHub token settings..."
    open "https://github.com/settings/personal-access-tokens"

    # Only back up if the config dir exists
    if [ -d "$CONFIG_DIR" ]; then
        # Remove any existing backups matching the pattern
        shopt -s nullglob  # allows the glob to expand to nothing if no matches
        for old_backup in "${CONFIG_DIR}.backup."*; do
            rm -rf "$old_backup"
        done
        shopt -u nullglob

        # Move current config to a new timestamped backup
        timestamp=$(date +%s)
        mv "$CONFIG_DIR" "${CONFIG_DIR}.backup.$timestamp"
    fi

    echo "Starting clone... Please look for the 'Username' and 'Password' prompts below."
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

# Apply nix-darwin configuration (requires root)
echo "Applying system configuration via nix-darwin."
cd "$CONFIG_DIR"

echo "Injecting dynamic username into Nix configuration..."

# Get the real human user (even under sudo)
REAL_USER=$(stat -f '%Su' /dev/console)

# Add the modified file to git so the Nix Flake can see the changes
if ! git diff --quiet darwin-configuration.nix; then
    git add darwin-configuration.nix
fi

# Move existing shell profiles so nix-darwin can take over
for file in /etc/bashrc /etc/zshrc; do
    # ONLY move if it's a real file (-f) AND NOT a symbolic link (! -L)
    if [ -f "$file" ] && [ ! -L "$file" ] && [ ! -e "$file.before-nix-darwin" ]; then
        sudo mv "$file" "$file.before-nix-darwin"
    fi
done

echo "Nix is applying system-wide changes (requires sudo)..."
sudo nix run github:LnL7/nix-darwin -- switch --flake .#default

echo "=== Real Nix bootstrap complete ==="
