#!/usr/bin/env bash

set -Eeuo pipefail

echo "=== LibreChat Bootstrap ==="

APPS_DIR="${HOME}/apps"
LIBRECHAT_DIR="${APPS_DIR}/LibreChat"

########################################
# Prerequisites
########################################

for cmd in git docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $cmd"
        exit 1
    fi
done

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose plugin not available."
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "WARNING: openssl not found."
    echo "You may need it later for generating secrets."
fi

########################################
# Docker daemon access
########################################

if ! docker info >/dev/null 2>&1; then
    echo
    echo "ERROR: Cannot access Docker daemon."
    echo
    echo "Try:"
    echo "  sudo systemctl start docker"
    echo
    echo "or add your user to the docker group:"
    echo "  sudo usermod -aG docker \"$USER\""
    echo "  (then log out and back in)"
    echo
    exit 1
fi

########################################
# Create workspace
########################################

mkdir -p "$APPS_DIR"

########################################
# Clone LibreChat if missing
########################################

if [[ -d "$LIBRECHAT_DIR/.git" ]]; then
    echo "LibreChat repository already exists:"
    echo "  $LIBRECHAT_DIR"
else
    echo "Cloning LibreChat..."

    git clone \
        https://github.com/danny-avila/LibreChat.git \
        "$LIBRECHAT_DIR"

    echo "Clone complete."
fi

########################################
# Create .env if missing
########################################

cd "$LIBRECHAT_DIR"

if [[ -f .env ]]; then
    echo ".env already exists."
else
    if [[ ! -f .env.example ]]; then
        echo "ERROR: .env.example not found."
        echo "Repository layout may have changed."
        exit 1
    fi

    cp .env.example .env
    echo "Created .env from .env.example"
fi

########################################
# Summary
########################################

echo
echo "========================================="
echo "LibreChat bootstrap complete"
echo "========================================="
echo
echo "Repository:"
echo "  $LIBRECHAT_DIR"
echo
echo "Next steps:"
echo
echo "1. Review repository documentation"
echo
echo "   cd $LIBRECHAT_DIR"
echo
echo "   Check the README and current LibreChat"
echo "   documentation for any setup changes."
echo
echo "2. Configure endpoints (multi-provider support)"
echo
echo "   Locate the example YAML configuration"
echo "   file provided by the current release."
echo
echo "   Copy it to librechat.yaml if required."
echo
echo "   Configure providers such as:"
echo "     - Gemini"
echo "     - OpenAI"
echo "     - Anthropic"
echo
echo "3. Edit environment file"
echo
echo "   nano .env"
echo
echo "   Add API keys as required by the"
echo "   current LibreChat version."
echo
echo "4. Review any required secrets"
echo
echo "   Consult the current LibreChat"
echo "   documentation before first startup."
echo
echo "5. Review docker-compose.yml"
echo
echo "6. Pull images and start LibreChat manually"
echo
echo "   docker compose pull"
echo "   docker compose up -d"
echo
echo "7. Follow logs"
echo
echo "   docker compose logs -f"
echo
echo "8. Open"
echo
echo "   http://localhost:3080"
echo
echo "This script does NOT:"
echo "  - install Docker"
echo "  - upgrade Docker"
echo "  - modify Git configuration"
echo "  - use GitHub authentication"
echo "  - modify pyenv"
echo "  - modify Python installations"
echo "  - start LibreChat automatically"
echo "  - generate secrets or passwords"
echo "  - auto-edit configuration files"
echo "  - pull repository updates"
echo
