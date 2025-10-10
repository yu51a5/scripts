#!/bin/bash

# This script is intended to be sourced by other scripts.
# It ensures a Python virtual environment exists and exports the PYTHON_CMD variable.
# It will exit with an error if a virtual environment cannot be found or created.

set -e

# This function encapsulates all the logic.
ensure_venv() {
    local VENV_DIR="venv"
    # Note: We check for the python executable directly for robustness.
    local VENV_PYTHON="${VENV_DIR}/bin/python"

    if [ ! -f "$VENV_PYTHON" ]; then
        echo "🐍 Python virtual environment not found. Attempting to create it..."
        
        # Check for system python3 first, which is needed to create the venv.
        if ! command -v python3 &> /dev/null; then
            echo "❌ Error: 'python3' is not installed or not in your PATH." >&2
            echo "A system-level Python 3 is required to create the virtual environment." >&2
            exit 1
        fi

        # Try to create the venv using robust logic.
        if ! python3 -m venv "$VENV_DIR"; then
            echo "⚠️ Virtual environment creation failed. Checking for a common Debian/Ubuntu issue..."
            if command -v apt &> /dev/null; then
                local PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
                local VENV_PKG="python${PY_VERSION}-venv"
                
                read -p "Attempt to install '${VENV_PKG}' with sudo? (y/N) " response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    sudo apt update && sudo apt install -y "$VENV_PKG"
                    echo "✅ Retrying venv creation..."
                    python3 -m venv "$VENV_DIR"
                else
                    echo "❌ Installation aborted. Please install '${VENV_PKG}' manually."
                    exit 1
                fi
            else
                echo "❌ Virtual environment creation failed for an unknown reason." >&2
                exit 1
            fi
        fi
        
        echo "✅ Virtual environment created successfully."
        
        # Install essential packaging tools into the new venv.
        echo "🔧 Installing essential packaging tools (build, twine)..."
        "$VENV_PYTHON" -m pip install --upgrade build twine
    fi

    # Export the variable for the calling script to use. This is the crucial part.
    export PYTHON_CMD="$VENV_PYTHON"
}

# Call the function as soon as the script is sourced.
ensure_venv