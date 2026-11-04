#!/bin/bash

set -e

DIR_PATH=$(dirname "$(readlink -f "$0")")
cd "$DIR_PATH"

# Initialize Git Submodules
git submodule update --init --recursive

# Initialize configuration files
if [ ! -f "./configure.conf" ]; then
    cp ./configure.conf.default ./configure.conf
fi

if [ ! -f "./docker-compose.yml" ]; then
    cp ./docker-compose.yml.default ./docker-compose.yml
fi

if [ ! -f "./update.sh" ]; then
    cp ./update.sh.default ./update.sh
    chmod +x ./update.sh
fi

# Install required host packages
if ! command -v socat >/dev/null 2>&1; then
    echo "[INFO] Installing socat..."
    sudo apt-get update
    sudo apt-get install -y socat
fi

# Initialize runtime directory for Unix sockets
mkdir -p ./runtime

# Check required configuration
if grep -qE '^(CAMERA_ID|AIAPIKEY)=<[^>]+>' ./configure.conf; then
    echo ""
    echo "Please edit configure.conf before starting."
    echo "Run: nano configure.conf"
else
    echo ""
    echo "Setup completed."
    echo "Run: docker --context rootless compose up -d --build"
fi
