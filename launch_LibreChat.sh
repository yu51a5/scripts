#!/usr/bin/env bash
set -Eeuo pipefail

export UID=$(id -u)
export GID=$(id -g)

cd "$HOME/apps/LibreChat"
docker compose up -d
