#!/bin/bash
# A reusable script to set up and run a Python project.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. Load Project-Specific Configuration ---
# Check for a .env file in the current directory and load it if it exists.
if [ -f ".env" ]; then
    echo "✅ Found .env file. Loading project-specific configuration..."
    # Use 'allexport' to export all variables defined in the .env file.
    set -o allexport
    source .env
    set +o allexport
fi

# --- 2. Set Default Configuration ---
# Use shell parameter expansion: ${VAR:-"default_value"}
# This uses the value from the .env file if set, otherwise it uses the default.
VENV_DIR=${VENV_DIR:-"venv"}
REQUIREMENTS_FILE=${REQUIREMENTS_FILE:-"requirements.txt"}
MAIN_SCRIPT=${MAIN_SCRIPT:-"main.py"}
PYTHON_CMD=${PYTHON_CMD:-"python3"}

# --- Script Logic (largely unchanged) ---

# Check if python3 is installed
if ! command -v $PYTHON_CMD &> /dev/null
then
    echo "Error: '$PYTHON_CMD' is not installed or not in your PATH." >&2
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "✅ Creating virtual environment at './$VENV_DIR'..."
    $PYTHON_CMD -m venv $VENV_DIR
else
    echo "👍 Virtual environment already exists."
fi

# Install packages from requirements.txt
VENV_PIP="$VENV_DIR/bin/pip"
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "📦 Installing/updating dependencies from '$REQUIREMENTS_FILE'..."
    $VENV_PIP install -r $REQUIREMENTS_FILE
else
    echo "⚠️ Warning: '$REQUIREMENTS_FILE' not found. Skipping dependency installation."
fi

# Run the project
VENV_PYTHON="$VENV_DIR/bin/python"
if [ -f "$MAIN_SCRIPT" ]; then
    echo "🚀 Running project: $MAIN_SCRIPT..."
    echo "----------------------------------------"
    $VENV_PYTHON $MAIN_SCRIPT
else
    echo "Error: Main script '$MAIN_SCRIPT' not found." >&2
    exit 1
fi

echo "----------------------------------------"
echo "✅ Script finished."