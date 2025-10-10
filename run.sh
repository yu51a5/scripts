#!/bin/bash
set -e

# Source the common environment setup script. This handles all venv logic
# and provides the $PYTHON_CMD variable.
source "$(dirname "$0")/_env.sh"

# Load project-specific .env file if it exists
if [ -f ".env" ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Configuration with defaults
REQUIREMENTS_FILE=${REQUIREMENTS_FILE:-"requirements.txt"}
MAIN_SCRIPT=${MAIN_SCRIPT:-"main.py"}

# --- Script's Main Task ---
echo "👍 Using Python from: $PYTHON_CMD"

# Install dependencies
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "📦 Installing dependencies from '$REQUIREMENTS_FILE'..."
    "$PYTHON_CMD" -m pip install -r "$REQUIREMENTS_FILE"
else
    echo "⚠️ Warning: '$REQUIREMENTS_FILE' not found. Skipping dependency installation."
fi

# Run the project
if [ -f "$MAIN_SCRIPT" ]; then
    echo "🚀 Running project: $MAIN_SCRIPT..."
    echo "----------------------------------------"
    "$PYTHON_CMD" "$MAIN_SCRIPT"
else
    echo "❌ Error: Main script '$MAIN_SCRIPT' not found." >&2
    exit 1
fi

echo "✅ Script finished."