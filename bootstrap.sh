#!/usr/bin/env bash
# Bootstrap for Nix + nix-darwin

set -euo pipefail

# Force the script to start in the user's home directory
cd "$HOME"

PRIVATE_REPO="github:optevo/nix-config"      # Private repo
CONFIG_DIR="${HOME}/.config/nix"             # Private Nix configuration

echo "=== Starting real Nix bootstrap ==="
echo "Config directory: $CONFIG_DIR"

# 1. Install Apple Developer Tools if needed
echo "Step 1: Checking Apple Developer Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Apple Developer Tools..."
    xcode-select --install
else
    echo "Apple Developer Tools already installed."
fi

# 2. Install Nix if missing
echo "Step 2: Checking Nix..."

NIX_DAEMON_SCRIPT="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

# Load Nix environment if the daemon script exists
if [ -r "$NIX_DAEMON_SCRIPT" ]; then
    . "$NIX_DAEMON_SCRIPT"
fi

# Install only if daemon script is missing or nix command is not available
if [ ! -r "$NIX_DAEMON_SCRIPT" ] || ! command -v nix >/dev/null 2>&1; then
    echo "Nix not found — installing via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
else
    echo "Nix already installed."
fi

# 3. Load Nix environment
echo "Step 3: Loading Nix environment..."
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# 4. Clone private repo using HTTPS and Personal Access Token (PAT)
echo "Step 4: Clone private repo using HTTPS and Personal Access Token (PAT)..."

CONFIG_DIR="$HOME/.config/nix"
PRIVATE_REPO="https://github.com/optevo/nix-config.git"

echo "You need a GitHub Personal Access Token (PAT) to access the private repo."
echo "The token must have read/write Contents permission on the repository."
echo "If you can't see the token you previously generated, you may need to regenerate it."
echo "If you haven't generated one yet, your browser will open GitHub's token page."

read -p "Press Enter to open GitHub token settings page in your browser..."

# Open GitHub token page
open "https://github.com/settings/personal-access-tokens"

# Prompt for the token
read -rsp "Enter your personal access token (it will be hidden): " GITHUB_PAT
echo

# Ensure config directory is empty and owned by the user
if [ -d "$CONFIG_DIR" ]; then
    echo "Removing old config directory (requires sudo)..."
    sudo rm -rf "$CONFIG_DIR"
fi
mkdir -p "$CONFIG_DIR"
echo "Changing config directory ownership (requires sudo)..."
sudo chown -R "$USER:staff" "$CONFIG_DIR"

# Then clone
echo "Cloning private repo..."
git clone -c credential.helper= "https://oauth2:${GITHUB_PAT}@github.com/optevo/nix-config.git" "$CONFIG_DIR"

# 5. Apply nix-darwin configuration (requires root)
echo "Step 5: Applying system configuration via nix-darwin."
cd "$CONFIG_DIR"

# --- DYNAMIC USER INJECTION ---
echo "Injecting dynamic username into Nix configuration..."

# 1. Get the real human user (even under sudo)
REAL_USER=$(stat -f '%Su' /dev/console)

# 2. Find the line with the marker and replace whatever is in the quotes with the real user
sed -i '' -E "s/system\.primaryUser = \".*\"; # @USER_MARKER@/system.primaryUser = \"$REAL_USER\"; # @USER_MARKER@/" "darwin-configuration.nix"

# 3. Add the modified file to git so the Nix Flake can see the changes
git add darwin-configuration.nix
# ------------------------------

# Move existing shell profiles so nix-darwin can take over
for file in /etc/bashrc /etc/zshrc; do
    # ONLY move if it's a real file (-f) AND NOT a symbolic link (! -L)
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        echo "Backing up native $file (requires sudo)..."
        sudo mv "$file" "$file.before-nix-darwin"
    fi
done

echo "Nix is applying system-wide changes (requires sudo)..."
sudo nix run github:LnL7/nix-darwin -- switch --flake .#default

echo "=== Real Nix bootstrap complete ==="
