#!/usr/bin/env bash
# Dummy Bootstrap Script for Nix + nix-darwin
# Safe for public use. Does not clone any private repos.

set -euo pipefail

echo "=== Dummy Nix Bootstrap ==="
echo "This script simulates the steps of a real bootstrap without affecting your system."

# 1. Check Apple Developer Tools
echo "Step 1: Checking Apple Developer Tools..."
if xcode-select -p >/dev/null 2>&1; then
    echo "Apple Developer Tools already installed."
else
    echo "Apple Developer Tools not found. Would run: xcode-select --install"
fi

# 2. Check Nix installation
echo "Step 2: Checking Nix..."
if command -v nix >/dev/null 2>&1; then
    echo "Nix is already installed."
else
    echo "Nix not found. Would run: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
fi

# 3. Load Nix environment
echo "Step 3: Loading Nix environment..."
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    echo "Would source: /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
else
    echo "Nix daemon script not found. Skipping load."
fi

# 4. GitHub CLI authentication
echo "Step 4: Authenticate GitHub CLI..."
echo "Would run: nix run nixpkgs#gh -- auth login"

# 5. Clone private repo (dummy)
PRIVATE_REPO="${HOME}/.config/nix"
echo "Step 5: Cloning private repo into $PRIVATE_REPO..."
if [ ! -d "$PRIVATE_REPO/.git" ]; then
    echo "Would clone private Nix configuration here."
else
    echo "Private repo already exists. Would pull latest changes."
fi

# 6. Apply system configuration (dummy)
echo "Step 6: Apply system configuration..."
echo "Would run: nix run github:LnL7/nix-darwin -- switch --flake $PRIVATE_REPO"

echo "=== Dummy Bootstrap Complete ==="
