#!/bin/bash
set -euo pipefail

# Installs Rokit (rojo-rbx/rokit) instead of Aftman, then runs your usual tool steps.

if command -v rokit >/dev/null 2>&1; then
    echo "You've already installed rokit on your PC"
else
    REPO="rojo-rbx/rokit"
    GITHUB_API_URL="https://api.github.com/repos/${REPO}/releases/latest"

    # Detect OS
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$OS" in
        darwin) OS="macos" ;;
        linux) OS="linux" ;;
        cygwin*|mingw*|msys*) OS="windows" ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    # Detect arch
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|x86-64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="aarch64" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    # Get latest tag (e.g. v1.2.0)
    RELEASE_JSON="$(curl -sSf -H "X-GitHub-Api-Version: 2022-11-28" "$GITHUB_API_URL")"
    TAG="$(echo "$RELEASE_JSON" | grep -oP '"tag_name"\s*:\s*"\Kv[^"]+')"

    if [[ -z "${TAG:-}" ]]; then
        echo "Failed to determine latest rokit release tag."
        exit 1
    fi

    VERSION="${TAG#v}"
    EXT=""
    BIN="rokit"
    if [[ "$OS" == "windows" ]]; then
        EXT=".exe"
        BIN="rokit.exe"
    fi

    ASSET="rokit-${VERSION}-${OS}-${ARCH}.zip"
    URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

    TMPDIR="$(mktemp -d)"
    cleanup() { rm -rf "$TMPDIR"; }
    trap cleanup EXIT

    echo "Downloading rokit from $URL..."
    curl -L -o "$TMPDIR/rokit.zip" "$URL"

    # Extract only the binary from the zip (the official zips contain rokit/rokit.exe at root)
    unzip -o -q "$TMPDIR/rokit.zip" "$BIN" -d "$TMPDIR"

    if [[ ! -f "$TMPDIR/$BIN" ]]; then
        echo "Downloaded archive did not contain expected binary: $BIN"
        exit 1
    fi

    if [[ "$OS" != "windows" ]]; then
        chmod +x "$TMPDIR/$BIN"
    fi

    echo "Running rokit self-install..."
    "$TMPDIR/$BIN" self-install

    # Ensure PATH includes Rokit's bin directory
    line_to_add='export PATH=$PATH:~/.rokit/bin'

    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -Fxq "$line_to_add" "$HOME/.bashrc"; then
            echo "$line_to_add" >> "$HOME/.bashrc"
        fi
    else
        echo "$line_to_add" > "$HOME/.bashrc"
    fi

    # Load PATH for current shell (best effort)
    # shellcheck disable=SC1090
    source "$HOME/.bashrc" || true
fi

# Equivalent flow to your old script:
rokit install
# shellcheck disable=SC1090
source "$HOME/.bashrc" || true
./update.sh
# shellcheck disable=SC1090
source "$HOME/.bashrc" || true
rojo plugin install
