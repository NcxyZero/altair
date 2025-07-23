#!/bin/bash

if command -v aftman >/dev/null; then
    echo "You've already installed aftman on your PC"
else
    GITHUB_API_URL="https://api.github.com/repos/LPGhatguy/aftman/releases/latest"

    mkdir -p "$DOWNLOAD_DIR"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
        EXT=""
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
        EXT=""
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        PLATFORM="windows"
        EXT=".exe"
    else
        echo "Unsupported OS: $OSTYPE"
        exit 1
    fi

    rm $HOME/aftman.zip
    rm ./aftman$EXT

    RELEASE_INFO=$(curl -s "$GITHUB_API_URL")
    echo "$RELEASE_INFO"

    LATEST_RELEASE=$(echo "$RELEASE_INFO" | grep -oP "(?<=browser_download_url\": \")[^\"]*${PLATFORM}[^\"]*")
    echo "$LATEST_RELEASE"

    if [[ -z "$LATEST_RELEASE" ]]; then
    echo "Failed to find a release for $PLATFORM."
    exit 1
    fi
    AFTMAN_PATH="$HOME/aftman$EXT"

    echo "Downloading aftman from $LATEST_RELEASE..."
    curl -L "$LATEST_RELEASE" -o "$HOME/aftman.zip"
    unzip $HOME/aftman.zip

    if [[ "$PLATFORM" != "windows" ]]; then
        chmod +x ./aftman
        ./aftman self-install
    else
        ./aftman.exe self-install
    fi

    rm $HOME/aftman.zip
    rm ./aftman$EXT
    line_to_add='export PATH=$PATH:~/.aftman/bin'

    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -Fxq "$line_to_add" "$HOME/.bashrc"; then
            echo "$line_to_add" >> "$HOME/.bashrc"
        fi
    else
        echo "$line_to_add" > "$HOME/.bashrc"
    fi

    source ~/.bashrc
fi

aftman install
source ~/.bashrc
./update.sh
source ~/.bashrc
rojo plugin install
