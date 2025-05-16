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
LOCK_FILE="$DIR/update_lock.pid"

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

# Delete log if bigger than 1GB
if [ "$(stat -c%s "$LOG_FILE")" -gt $((1*1024*1024*1024)) ]; then
    > "$LOG_FILE"
fi

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check for existing lock
if [ -f "$LOCK_FILE" ]; then
    existing_pid=$(cat "$LOCK_FILE")
    if ps -p "$existing_pid" > /dev/null 2>&1; then
        # Process exists: log scheduled time and remaining time
        if [ -f "$PAUSE_FILE" ]; then
            scheduled_time=$(cat "$PAUSE_FILE")
            if [[ "$scheduled_time" =~ ^[0-9]+$ ]]; then
                current_time=$(date +%s)
                if [ "$current_time" -lt "$scheduled_time" ]; then
                    remaining_seconds=$((scheduled_time - current_time))
                    log "Update already scheduled at $(date -d "@$scheduled_time" '+%Y-%m-%d %H:%M:%S'). Remaining time: $remaining_seconds seconds."
                else
                    log "Update process with PID $existing_pid is running, but scheduled time has passed."
                fi
            else
                log "Existing lock's schedule timestamp invalid."
            fi
        else
            log "Existing lock with PID $existing_pid found, but no schedule info."
        fi
        exit 0
    else
        # Stale lock, remove it
        rm -f "$LOCK_FILE"
    fi
fi

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
log "Target Bootstrap Node ($TARGET_ADDRESS) version: $target_version"

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

# Check if update is needed
if version_compare "$identity_version" "$target_version"; then
    log "No update needed. Validator version is up-to-date or newer."
    exit 0
else
    log "Validator version is older than target Bootstrap Node. Proceeding with scheduled update checks..."
fi

# Check or create scheduled update timestamp in pause file
current_time=$(date +%s)

if [ ! -f "$PAUSE_FILE" ]; then
    log "No scheduled update file found. Creating one..."
    rand_delay=$((RANDOM % (48*3600 + 1)))  # 0 to 48 hours
    scheduled_time=$((current_time + rand_delay))
    echo "$scheduled_time" > "$PAUSE_FILE"
    log "Scheduled update at $(date -d "@$scheduled_time" '+%Y-%m-%d %H:%M:%S')"
    # Schedule background update
    (
        sleep "$rand_delay" && "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1 && \
        echo "Update executed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    ) &
    echo $! > "$LOCK_FILE"
    exit 0
fi

# Read scheduled update timestamp
scheduled_time=$(cat "$PAUSE_FILE")
if ! [[ "$scheduled_time" =~ ^[0-9]+$ ]]; then
    log "Invalid timestamp in scheduled update file. Resetting..."
    rand_delay=$((RANDOM % (48*3600 + 1)))
    scheduled_time=$((current_time + rand_delay))
    echo "$scheduled_time" > "$PAUSE_FILE"
    log "Rescheduled update at $(date -d "@$scheduled_time" '+%Y-%m-%d %H:%M:%S')"
    (
        sleep "$((scheduled_time - current_time))" && "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1 && \
        echo "Update executed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    ) &
    echo $! > "$LOCK_FILE"
    exit 0
fi

# Check if scheduled time has passed or is now
if [ "$current_time" -ge "$scheduled_time" ]; then
    # Time passed or exactly now: delete pause file, do NOT run update or schedule
    rm -f "$PAUSE_FILE"
    log "Scheduled update time ($scheduled_time) has passed. Deleted pause file. No update will be run now."
    # Remove lock if exists
    rm -f "$LOCK_FILE"
    exit 0
else
    # Not yet time: check if process is running
    remaining_seconds=$((scheduled_time - current_time))
    # Log scheduled time and remaining time
    log "Update scheduled at $(date -d "@$scheduled_time" '+%Y-%m-%d %H:%M:%S'). Remaining seconds: $remaining_seconds."
    # Check if a process is already running (should be checked earlier via lock, but double check)
    if [ -f "$LOCK_FILE" ]; then
        existing_pid=$(cat "$LOCK_FILE")
        if ps -p "$existing_pid" > /dev/null 2>&1; then
            log "Update process already running with PID $existing_pid. Exiting."
            exit 0
        fi
    fi
    # Start background sleep + update process
    (
        sleep "$remaining_seconds" && "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1 && \
        echo "Update executed at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    ) &
    echo $! > "$LOCK_FILE"
    exit 0
fi
