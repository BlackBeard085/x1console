#!/bin/bash

#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

# Directory containing all files
DIR="$HOME/x1console"

# Files
WALLETS_FILE="$DIR/wallets.json"
PAUSE_FILE="$DIR/update_pause_time.txt"
LOG_FILE="$DIR/validator_update.log"
UPDATE_SCRIPT="$DIR/update.sh"

# Config
TARGET_ADDRESS="Tpsu5EYTJAXAat19VEh54zuauHvUBuryivSFRC3RiFk"

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed." | tee -a "$LOG_FILE"
    exit 1
fi

if ! command -v date &> /dev/null; then
    echo "Error: date command not found." | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -x "$UPDATE_SCRIPT" ]; then
    echo "Error: $UPDATE_SCRIPT not found or not executable." | tee -a "$LOG_FILE"
    exit 1
fi

# Ensure log file exists
touch "$LOG_FILE"

# Delete log if bigger than 2GB
if [ "$(stat -c%s "$LOG_FILE")" -gt $((2*1024*1024*1024)) ]; then
    > "$LOG_FILE"
fi

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Extract the "Identity" address
identity_address=$(jq -r '.[] | select(.name=="Identity") | .address' "$WALLETS_FILE")
if [ -z "$identity_address" ]; then
    log "Could not find 'Identity' address in $WALLETS_FILE."
    exit 1
fi

# Get version for Identity address
identity_output=$(solana validators | grep "$identity_address")
if [ -z "$identity_output" ]; then
    log "No validator info for Identity address."
    exit 0
fi
identity_version=$(echo "$identity_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ -z "$identity_version" ]; then
    log "Version not found in identity validator output."
    exit 1
fi
log "Identity version: $identity_version"

# Get version for target address
target_output=$(solana validators | grep "$TARGET_ADDRESS")
if [ -z "$target_output" ]; then
    log "No validator info for target address."
    exit 0
fi
target_version=$(echo "$target_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ -z "$target_version" ]; then
    log "Version not found in target validator output."
    exit 1
fi
log "Target ($TARGET_ADDRESS) version: $target_version"

# Function to compare versions
version_compare() {
    if [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$1" ]]; then
        if [ "$1" == "$2" ]; then
            return 0  # equal
        else
            return 1  # $1 < $2
        fi
    else
        return 0  # $1 > $2
    fi
}

# Compare versions
if version_compare "$identity_version" "$target_version"; then
    log "No update needed. Identity version is up-to-date or newer."
    exit 0
else
    log "Identity version is older than target. Proceeding with pause checks..."
fi

# Check pause file
current_time=$(date +%s)

if [ ! -f "$PAUSE_FILE" ]; then
    log "No pause file found. Creating one..."
    echo "0" > "$PAUSE_FILE"
fi

pause_time=$(cat "$PAUSE_FILE")
if ! [[ "$pause_time" =~ ^[0-9]+$ ]]; then
    log "Invalid pause time in file. Resetting."
    pause_time=0
fi

# Calculate hours since last pause
time_diff_hours=$(((current_time - pause_time) / 3600))

if [ "$pause_time" -eq 0 ]; then
    log "Pause file is empty or reset. Creating new pause..."
    rand_delay=$((RANDOM % (48*3600 + 1)))  # 0 to 48 hours in seconds
    new_pause_time=$((current_time + rand_delay))
    echo "$new_pause_time" > "$PAUSE_FILE"
    log "Scheduled update in $rand_delay seconds (within 48 hours)."
    (sleep "$rand_delay" && "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1 && \
      echo "Update executed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE") &
    exit 0
fi

if [ "$time_diff_hours" -lt 48 ]; then
    log "Last update was less than 48 hours ago. No action."
    exit 0
else
    # More than 48 hours since last update
    log "More than 48 hours since last update. Updating validator..."
    # Run update and log output
    (
        echo "Running ./update.sh at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1
        echo "Update completed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    ) &
    # Set new pause time for next scheduled update (within 48 hours)
    rand_delay=$((RANDOM % (48*3600 + 1)))  # 0 to 48 hours in seconds
    new_pause_time=$((current_time + rand_delay))
    echo "$new_pause_time" > "$PAUSE_FILE"
    log "Scheduled next update in $rand_delay seconds (within 48 hours)."
    sleep "$rand_delay" && "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1 && \
     echo "Update executed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    exit 0
fi
