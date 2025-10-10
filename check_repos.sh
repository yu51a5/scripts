#!/bin/bash

# ==============================================================================
#  check_repos.sh (v2.1 - Corrected Count)
#
#  - Scans all sibling directories (including itself) for Git repositories.
#  - Reports if they have any local changes (modified, staged, or untracked).
#  - Correctly counts the total number of changed files.
#  - Lists the first 10 files with their status.
#
# ==============================================================================

# --- Color Definitions for pretty output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# This script is in 'scripts', so we go one level up to get the 'code' directory.
PARENT_DIR=$(cd "$(dirname "$0")/.." && pwd)

echo -e "${BLUE}🔎 Starting repository scan in: ${PARENT_DIR}${NC}"
echo "--------------------------------------------------"

# Loop through all subdirectories in the parent 'code' directory
for dir in "$PARENT_DIR"/*; do
    # We only care about directories
    if [ -d "$dir" ]; then

        # Check if the directory is a git repository by looking for a .git folder
        if [ -d "$dir/.git" ]; then
            repo_name=$(basename "$dir")

            # `printf` is used for nice, aligned formatting.
            printf '%-35s' "➔ Checking '$repo_name'..."

            # `git status --porcelain` provides a simple, script-friendly output.
            # If there are NO changes, the output is completely empty.
            changes=$(git -C "$dir" status --porcelain)

            # The `-n` test checks if the 'changes' string is not empty.
            if [ -n "$changes" ]; then
                # *** FIX: Use `grep -c .` to correctly count non-empty lines. ***
                count=$(echo -n "$changes" | grep -c .)

                # Get the first 10 lines and indent them with sed for nice formatting.
                file_list=$(echo "$changes" | head -n 10 | sed 's/^/    /')

                echo -e "${YELLOW}⚠️  Found ${count} changed/untracked file(s).${NC}"
                echo "${file_list}"
                if [ "$count" -gt 10 ]; then
                    echo "    ...and $(($count - 10)) more."
                fi
            else
                echo -e "${GREEN}✅  Clean.${NC}"
            fi
        fi
    fi
done

echo "--------------------------------------------------"
echo -e "${BLUE}✨ Scan complete.${NC}"