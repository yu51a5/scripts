#!/bin/bash
set -e

# Source the common environment setup script. This handles all venv logic
# and provides the $PYTHON_CMD variable.
source "$(dirname "$0")/_env.sh"

# --- Default Settings, Help, and Arg Parsing (unchanged) ---
CLEANUP=true
BUILD_ONLY=false
UPLOAD_TARGET="pypi"

show_help() {
    echo "Usage: $(basename "$0") [-h] [-n] [-b] [-t]"
    echo -e "\nOptions:\n  -h\tDisplay this help message.\n  -n\tNo cleanup of old build directories.\n  -b\tBuild only, do not upload.\n  -t\tUpload to TestPyPI instead of real PyPI."
}

while getopts "hnbt" opt; do
    case "$opt" in
        h) show_help; exit 0;;
        n) CLEANUP=false;;
        b) BUILD_ONLY=true;;
        t) UPLOAD_TARGET="testpypi";;
        *) show_help; exit 1;;
    esac
done

# --- Script's Main Task ---
PACKAGE_NAME=$(basename "$(pwd)")
echo "👍 Using Python from: $PYTHON_CMD"
echo "▶️  Starting publish process for package: $PACKAGE_NAME"

# Cleanup
if [ "$CLEANUP" = true ]; then
    echo "🧹 Cleaning up old build artifacts..."
    rm -rf dist build *.egg-info
else
    echo "⏩ Skipping cleanup step."
fi

# Build
echo "🏗️ Building package..."
"$PYTHON_CMD" -m build

# Upload
if [ "$BUILD_ONLY" = true ]; then
    echo "✅ Build complete. Skipping upload."
    ls -l dist
else
    if [ "$UPLOAD_TARGET" = "testpypi" ]; then
        echo "📦 Uploading to TestPyPI..."
        "$PYTHON_CMD" -m twine upload --repository testpypi dist/*
    else
        echo "📦 Uploading to the real PyPI..."
        "$PYTHON_CMD" -m twine upload dist/*
    fi
fi

echo "✅ Process finished."