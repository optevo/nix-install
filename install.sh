#!/usr/bin/env bash
# Bootstrap for Nix + nix-darwin

if [ "$(id -u)" -eq 0 ]; then
    echo "This script should NOT be run with sudo. Please run as your normal user."
    exit 1
fi

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

# 4. Sync private configuration repository
echo "Step 4: Syncing private configuration repository..."

CONFIG_DIR="$HOME/.config/nix"
REPO_URL="https://github.com/optevo/nix-config.git"

# Tell Git to use the macOS Keychain (saves the token for future runs)
git config --global credential.helper osxkeychain

if [ -d "$CONFIG_DIR/.git" ]; then
    echo "Repository exists. Updating..."
    cd "$CONFIG_DIR"
    sudo chown -R "$USER:staff" "."
    git fetch origin
    git reset --hard origin/main
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

    # Clean up any non-git folder that might be in the way
    [ -d "$CONFIG_DIR" ] && sudo rm -rf "$CONFIG_DIR"

    echo "Starting clone... Please look for the 'Username' and 'Password' prompts below."
    
    # Git will now prompt you natively and save the result to your Keychain
    git clone "$REPO_URL" "$CONFIG_DIR"
    sudo chown -R "$USER:staff" "$CONFIG_DIR"
fi

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
