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

PRIVATE_REPO="github:optevo/nix-config"      # Private repo
CONFIG_DIR="${HOME}/.config/nix"             # Private Nix configuration

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

# Check if Nix is available
NIX_DAEMON_SCRIPT="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

# Install if missing
if ! command -v nix >/dev/null 2>&1; then
    echo "Nix not found — installing..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# Always try to load environment (idempotent)
if [ -r "$NIX_DAEMON_SCRIPT" ]; then
    echo "Loading Nix environment..."
    . "$NIX_DAEMON_SCRIPT"
fi

# Final sanity check
if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Nix is installed but not available in this shell."
    echo "Please restart your terminal and re-run the script."
    exit 1
fi

# Sync private configuration repository
echo "Syncing private configuration repository..."

REPO_URL="https://github.com/optevo/nix-config.git"

# Tell Git to use the macOS Keychain (saves the token for future runs)
git config --global credential.helper osxkeychain

if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Repository exists. Updating..."
    cd "$CONFIG_DIR"

# Check for local changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Warning: local changes detected in $CONFIG_DIR!"
    git status
    read -p "Do you want to discard these changes and reset to origin/main? [y/N]: " yn
    case "$yn" in
        [Yy]* ) git reset --hard origin/main ;;
        * ) echo "Aborting bootstrap."; exit 1 ;;
    esac
    else
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
        # Clean up old backup(s) before creating a new one
        for old in "${CONFIG_DIR}.backup."*; do
            [ -e "$old" ] && rm -rf "$old"
        done

        # Move current config to a timestamped backup
        mv "$CONFIG_DIR" "${CONFIG_DIR}.backup.$(date +%s)"
    fi

    echo "Starting clone... Please look for the 'Username' and 'Password' prompts below."
    
    # Git will now prompt you natively and save the result to your Keychain
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

# Apply nix-darwin configuration (requires root)
echo "Applying system configuration via nix-darwin."
cd "$CONFIG_DIR"

echo "Injecting dynamic username into Nix configuration..."

# Get the real human user (even under sudo)
REAL_USER=$(stat -f '%Su' /dev/console)

# Find the line with the marker and replace whatever is in the quotes with the real user
sed -i '' -E "s/system\.primaryUser = \".*\"; # @USER_MARKER@/system.primaryUser = \"$REAL_USER\"; # @USER_MARKER@/" "darwin-configuration.nix"

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
