# Nix Bootstrap / Installer / Updater

This repository provides a public installer for setting up Nix and nix-darwin on macOS (M-series).

It is intended to get a Mac into a state where it can pull a **private Nix configuration repo** and apply the system configuration.  

## Overview

1. Installs Apple Developer Tools if needed.
2. Installs Nix via the Determinate Systems installer.
3. Loads Nix into the current shell.
4. Authenticates with GitHub CLI or Keychain.
5. Clones the private Nix configuration repo into `~/.config/nix`.
6. Applies the system configuration via nix-darwin.

> **Note:** Step 5 requires access to a private repository and is not included in this public repo.

## Usage

Run the script directly:

```sh
bash <(curl -sL https://raw.githubusercontent.com/optevo/nix-install/main/install.sh)
