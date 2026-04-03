#!/usr/bin/env bash
# Bootstrap for Nix + nix-darwin

set -euo pipefail

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
echo "The token must have **read/write Contents permission on the repository."
echo "If you can't see the token you previously generated, you may need to regenerate it."
echo "If you haven't generated one yet, your browser will open GitHub's token page."
read -p "Press Enter to open GitHub token settings page in your browser..."

open "https://github.com/settings/personal-access-tokens"

read -rsp "Enter your PAT (it will be hidden): " GITHUB_PAT
echo

# Remove any existing clone to avoid credential issues
if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Removing old config repo to ensure new token is used..."
    rm -rf "$CONFIG_DIR"
fi

echo "Cloning private repo..."
git clone "https://${GITHUB_PAT}@github.com/optevo/nix-config.git" "$CONFIG_DIR"

# 5. Apply nix-darwin configuration (requires root)
echo "Step 5: Applying system configuration via nix-darwin (requires sudo)..."
cd "$CONFIG_DIR"
echo "Note: You will be prompted for your password to apply system-wide changes."
sudo nix run github:LnL7/nix-darwin -- switch --flake .

echo "=== Real Nix bootstrap complete ==="
