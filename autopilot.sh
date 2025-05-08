#!/bin/bash
#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"
#export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Define log file paths
RESTART_COUNT_LOG="$HOME/x1console/restart_count.log"
TIMESTAMP_FILE="$HOME/x1console/last_reset_timestamp.txt"
RESTART_TIMES_LOG="$HOME/x1console/restart_times.log"

# Function to reset logs
reset_logs() {
    echo "0" > "$RESTART_COUNT_LOG"
    echo "$(date +%s)" > "$TIMESTAMP_FILE"
    > "$RESTART_TIMES_LOG"  # Clear the restart times log
}

# Check when the logs were last reset
if [ ! -f "$TIMESTAMP_FILE" ]; then
    reset_logs
fi

LAST_RESET=$(cat "$TIMESTAMP_FILE")
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_RESET))

# Reset logs if more than 48 hours (172800 seconds) have passed
if [ "$TIME_DIFF" -ge 172800 ]; then
    reset_logs
fi

# Read the current restart count
RESTART_COUNT=$(cat "$RESTART_COUNT_LOG")

echo -e "\nSetting withdrawer..."
node "$HOME/x1console/setwithdrawer.js"

echo -e "\nRunning health.js..."
HEALTH_OUTPUT=$(node "$HOME/x1console/health.js")
echo -e "$HEALTH_OUTPUT"

if echo "$HEALTH_OUTPUT" | grep -q "WARNING"; then
    echo -e "\nWARNING issued in health check."

    # Log the time of the warning
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Validator status Delinquent - Restarted with Autopilot" >> "$RESTART_TIMES_LOG"

    # Increment the restart count
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "$RESTART_COUNT" > "$RESTART_COUNT_LOG"

    # Execute checkaccounts.js before getbalances.js
    echo -e "\nForce stopping validator..."
    pkill -f tachyon-validator

    echo -e "\nRemoving ledger..."
    rm -rf ~/x1/ledger

    echo -e "\nChecking accounts..."
    node "$HOME/x1console/checkaccounts.js"

    echo -e "\nChecking balances..."
    node "$HOME/x1console/getbalances.js"

    echo -e "\nChecking stake..."
    STAKE_OUTPUT=$(node "$HOME/x1console/checkstake.js")
    echo -e "$STAKE_OUTPUT"

    if echo "$STAKE_OUTPUT" | grep -q "0 active stake"; then
        echo -e "\n0 active stake found. Running activate stake..."
        node "$HOME/x1console/activatestake.js"

       #echo -e "\nAttempting restart after activating stake..."
        #node "$HOME/x1console/restart.js"
    else
        echo -e "\nActive stake found. Attempting restart..."
        node "$HOME/x1console/restart.js"
    fi
else
    echo -e "\nNo WARNING issued in health check. Exiting.\n"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Validator status Active - No Action taken" >> "$RESTART_TIMES_LOG"
fi
