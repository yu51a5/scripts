#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# Usage
########################################

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <secrets-file> [provider]"
    echo
    echo "Examples:"
    echo "  $0 ./ai-secrets.env            # Reset all providers to first key"
    echo "  $0 ./ai-secrets.env GOOGLE     # Rotate Google key only"
    echo "  $0 ./ai-secrets.env openai     # Rotate OpenAI key only (case-insensitive)"
    exit 1
fi

########################################
# Configuration
########################################

LIBRECHAT_DIR="$HOME/apps/LibreChat"
LIBRECHAT_ENV="$LIBRECHAT_DIR/.env"
SECRETS_FILE="$1"
# Capture and upcase the target provider for case-insensitive matching (Bash 3.2 portable)
ROTATE_PROVIDER="${2:-}"
if [[ -n "$ROTATE_PROVIDER" ]]; then
    ROTATE_PROVIDER=$(printf '%s\n' "$ROTATE_PROVIDER" | tr '[:lower:]' '[:upper:]')
fi

########################################
# Validation
########################################

[[ -d "$LIBRECHAT_DIR" ]] || {
    echo "ERROR: LibreChat directory not found:"
    echo "  $LIBRECHAT_DIR"
    exit 1
}

[[ -f "$LIBRECHAT_ENV" ]] || {
    echo "ERROR: LibreChat .env not found:"
    echo "  $LIBRECHAT_ENV"
    exit 1
}

[[ -f "$SECRETS_FILE" ]] || {
    echo "ERROR: Secrets file not found:"
    echo "  $SECRETS_FILE"
    exit 1
}

########################################
# Load secrets safely
########################################

declare -A SECRETS

while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$key" ]] && continue
    
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    SECRETS["$key"]="$value"
done < "$SECRETS_FILE"

########################################
# Helper Functions
########################################

count_keys() {
    local value="$1"
    if [[ -z "$value" ]]; then
        echo 0
        return
    fi
    IFS=',' read -ra keys <<< "$value"
    echo "${#keys[@]}"
}

get_key_at_index() {
    local value="$1"
    local idx="$2"
    IFS=',' read -ra keys <<< "$value"
    local trimmed=()
    for k in "${keys[@]}"; do
        k=$(echo "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        trimmed+=("$k")
    done
    if [[ $idx -ge 0 && $idx -lt ${#trimmed[@]} ]]; then
        echo "${trimmed[$idx]}"
    fi
}

find_key_index() {
    local value="$1"
    local target="$2"
    IFS=',' read -ra keys <<< "$value"
    for i in "${!keys[@]}"; do
        local k=$(echo "${keys[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$k" == "$target" ]]; then
            echo "$i"
            return
        fi
    done
    echo -1
}

get_short_hash() {
    # Portable hashing: works on Linux (sha256sum) and macOS (shasum -a 256)
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | cut -c1-8
    else
        printf '%s' "$1" | shasum -a 256 | cut -c1-8
    fi
}

########################################
# Key selection logic
########################################

select_key() {
    local base="$1"
    local rotate_flag="$2"
    local value="${SECRETS[$base]:-}"

    if [[ -z "$value" ]]; then
        return
    fi

    local count=$(count_keys "$value")
    if [[ $count -eq 0 ]]; then
        return
    fi

    if [[ "$rotate_flag" == "no" ]]; then
        get_key_at_index "$value" 0
        return
    fi

    # Read current value, strip spaces
    local current_value=""
    current_value=$(awk -F= -v k="$base" '$1==k {print substr($0,index($0,"=")+1); exit}' "$LIBRECHAT_ENV")
    current_value=$(echo "$current_value" | sed 's/[[:space:]]*$//')

    local current_idx=$(find_key_index "$value" "$current_value")
    local next_idx=0

    if [[ $current_idx -ge 0 && $current_idx -lt $((count - 1)) ]]; then
        next_idx=$((current_idx + 1))
    fi

    get_key_at_index "$value" "$next_idx"
}

########################################
# Update helper
########################################

MISSING=()
UPDATED=()
APPENDED=()
ROTATED=()
CHANGES=0
BACKUP_FILE=""

create_backup() {
    if [[ -z "$BACKUP_FILE" ]]; then
        BACKUP_FILE="$LIBRECHAT_ENV.$(date +%Y%m%d-%H%M%S).bak"
        cp "$LIBRECHAT_ENV" "$BACKUP_FILE"
    fi
}

update_provider() {
    local base="$1"
    local rotate_flag="$2"

    local escaped_base=$(printf '%s\n' "$base" | sed 's/[][\/.^$*+?|(){}]/\\&/g')
    local value="${SECRETS[$base]:-}"
    
    if [[ -z "$value" ]]; then
        MISSING+=("$base")
        return
    fi

    local selected_key=$(select_key "$base" "$rotate_flag")

    if [[ -z "$selected_key" ]]; then
        MISSING+=("$base")
        return
    fi

    # Extract entire line to handle empty values correctly
    local existing_line=""
    existing_line=$(awk -F= -v k="$base" '$1==k {print $0; exit}' "$LIBRECHAT_ENV")

    if [[ -n "$existing_line" ]]; then
        local old_value="${existing_line#*=}"
        old_value=$(echo "$old_value" | sed 's/[[:space:]]*$//')
        
        if [[ "$old_value" != "$selected_key" ]]; then
            local hash_old=$(get_short_hash "$old_value")
            local hash_new=$(get_short_hash "$selected_key")
            ROTATED+=("$base: ${hash_old} → ${hash_new}")
            CHANGES=1
            
            # Escape &, \, and | for the sed replacement string
            local safe_key=$(printf '%s\n' "$selected_key" | sed 's/[&\\|]/\\&/g')
            
            create_backup
            sed -i.bak "s|^${escaped_base}=.*|${base}=${safe_key}|" "$LIBRECHAT_ENV"
            rm -f "$LIBRECHAT_ENV.bak"
        else
            UPDATED+=("$base")
        fi
    else
        create_backup
        echo "${base}=${selected_key}" >> "$LIBRECHAT_ENV"
        APPENDED+=("$base")
        CHANGES=1
    fi
}

########################################
# Generic provider discovery
########################################

discover_providers() {
    local providers=()
    for key in "${!SECRETS[@]}"; do
        if [[ "$key" == *_KEY ]]; then
            providers+=("$key")
        fi
    done
    printf '%s\n' "${providers[@]}"
}

########################################
# Determine if a provider should rotate
########################################

should_rotate() {
    local base="$1"
    local target="$2"

    if [[ -z "$target" ]]; then
        echo "no"
        return
    fi

    local short_name="$base"
    if [[ "$short_name" == *_API_KEY ]]; then
        short_name="${short_name%_API_KEY}"
    elif [[ "$short_name" == *_KEY ]]; then
        short_name="${short_name%_KEY}"
    fi

    if [[ "$target" == "$short_name" || "$target" == "$base" ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

########################################
# Process all discovered providers
########################################

PROVIDERS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && PROVIDERS+=("$line")
done < <(discover_providers)

if [[ ${#PROVIDERS[@]} -eq 0 ]]; then
    echo "WARNING: No *_KEY variables found in $SECRETS_FILE"
    exit 1
fi

# Pre-flight check: ensure the requested provider actually exists
if [[ -n "$ROTATE_PROVIDER" ]]; then
    TARGET_MATCHED=0
    for provider in "${PROVIDERS[@]}"; do
        if [[ $(should_rotate "$provider" "$ROTATE_PROVIDER") == "yes" ]]; then
            TARGET_MATCHED=1
            break
        fi
    done
    if [[ $TARGET_MATCHED -eq 0 ]]; then
        echo "ERROR: Provider '$ROTATE_PROVIDER' not found in $SECRETS_FILE"
        exit 1
    fi
fi

# Apply updates
for provider in "${PROVIDERS[@]}"; do
    rotate_flag=$(should_rotate "$provider" "$ROTATE_PROVIDER")
    update_provider "$provider" "$rotate_flag"
done

########################################
# Report
########################################

echo
echo "========================================="
echo "LibreChat secrets update complete"
echo "========================================="
echo
echo "Target: $LIBRECHAT_ENV"
echo "Source: $SECRETS_FILE"
[[ -n "$ROTATE_PROVIDER" ]] && echo "Rotation: $ROTATE_PROVIDER"
[[ -n "$BACKUP_FILE" ]] && echo "Backup created: $BACKUP_FILE"
echo

[[ ${#APPENDED[@]} -gt 0 ]] && { echo "Added:"; for k in "${APPENDED[@]}"; do echo "  - $k"; done; echo; }
[[ ${#UPDATED[@]} -gt 0 ]] && { echo "Updated (same key):"; for k in "${UPDATED[@]}"; do echo "  - $k"; done; echo; }
[[ ${#ROTATED[@]} -gt 0 ]] && { echo "Rotated:"; for k in "${ROTATED[@]}"; do echo "  - $k"; done; echo; }
[[ ${#MISSING[@]} -gt 0 ]] && { echo "WARNING: Missing or empty keys:"; for k in "${MISSING[@]}"; do echo "  - $k"; done; echo; }

if [[ $CHANGES -gt 0 ]]; then
    echo "Restart: cd $LIBRECHAT_DIR && docker compose restart"
else
    echo "No changes made. Restart not required."
fi

[[ ${#MISSING[@]} -eq 0 ]] || exit 1
