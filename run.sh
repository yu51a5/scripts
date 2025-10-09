#!/bin/bash
# A reusable script that can now handle the missing 'python3-venv' dependency.

set -e

# --- 1. Load Project-Specific Configuration ---
if [ -f ".env" ]; then
    echo "✅ Found .env file. Loading project-specific configuration..."
    set -o allexport
    source .env
    set +o allexport
fi

# --- 2. Set Default Configuration ---
VENV_DIR=${VENV_DIR:-"venv"}
REQUIREMENTS_FILE=${REQUIREMENTS_FILE:-"requirements.txt"}
MAIN_SCRIPT=${MAIN_SCRIPT:-"main.py"}
PYTHON_CMD=${PYTHON_CMD:-"python3"}

# --- Script Logic ---

if ! command -v $PYTHON_CMD &> /dev/null; then
    echo "Error: '$PYTHON_CMD' is not installed or not in your PATH." >&2
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "✅ Creating virtual environment at './$VENV_DIR'..."
    # --- NEW: Automatic Error Handling ---
    if ! $PYTHON_CMD -m venv $VENV_DIR; then
        echo "⚠️ Virtual environment creation failed. Checking for a common Debian/Ubuntu issue..."
        # Check if 'apt' exists, which is a good indicator of a Debian-based system
        if command -v apt &> /dev/null; then
            PY_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
            VENV_PKG="python${PY_VERSION}-venv"
            
            read -p "Attempt to install '${VENV_PKG}' with sudo? (y/N) " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                sudo apt update && sudo apt install -y "$VENV_PKG"
                echo "✅ Retrying venv creation..."
                $PYTHON_CMD -m venv $VENV_DIR
            else
                echo "Installation aborted. Please install '${VENV_PKG}' manually and re-run the script."
                exit 1
            fi
        else
            echo "❌ Virtual environment creation failed for an unknown reason." >&2
            exit 1
        fi
    fi
    # --- END of NEW block ---
else
    echo "👍 Virtual environment already exists."
fi

# Install/update dependencies
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
