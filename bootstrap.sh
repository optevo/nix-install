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
if ! command -v nix >/dev/null 2>&1; then
    echo "Installing Nix via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
else
    echo "Nix already installed."
fi

# 3. Load Nix environment
echo "Step 3: Loading Nix environment..."
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# 4. Authenticate GitHub CLI
echo "Step 4: GitHub CLI authentication..."
nix run nixpkgs#gh -- auth login

# 5. Clone or update the private Nix configuration
echo "Step 5: Cloning or updating private config..."
if [ ! -d "$CONFIG_DIR/.git" ]; then
    nix run nixpkgs#gh -- repo clone "$PRIVATE_REPO" "$CONFIG_DIR"
else
    git -C "$CONFIG_DIR" pull --ff-only
fi

# 6. Apply nix-darwin configuration
echo "Step 6: Applying system configuration via nix-darwin..."
cd "$CONFIG_DIR"
nix run github:LnL7/nix-darwin -- switch --flake .

echo "=== Real Nix bootstrap complete ==="
