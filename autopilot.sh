#!/bin/bash
#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"
#export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Define log file paths
RESTART_COUNT_LOG="$HOME/x1console/restart_count.log"
TIMESTAMP_FILE="$HOME/x1console/last_reset_timestamp.txt"
RESTART_TIMES_LOG="$HOME/x1console/restart_times.log"

# Read token and chat ID
#TOKEN=$(cat "$HOME/x1console/telegram_token.txt")
#CHAT_ID=$(cat "$HOME/x1console/chat_id.txt")

# Define paths
TOKEN_FILE="$HOME/x1console/telegram_token.txt"
CHAT_ID_FILE="$HOME/x1console/chat_id.txt"

# Check if token file exists before reading
if [ -f "$TOKEN_FILE" ]; then
    # Read token and chat ID
    TOKEN=$(cat "$TOKEN_FILE")
    CHAT_ID=$(cat "$CHAT_ID_FILE")

    # Define function after confirming files exist

send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

else
    # Token file does not exist; define an empty function or skip sending
    send_telegram_message() {
        echo "Telegram token not found. No message sent."
    }
fi
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
    BALANCE_OUTPUT=$($HOME/x1console/epoch_balances.sh)
    sleep 3
    send_telegram_message "$(echo -e "⚠️ Warning: Validator status delinquent. Restarting with Autopilot. \n\n$BALANCE_OUTPUT")"
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
        #node "$HOME/x1console/activatestake.js"
        ACTIVATE_OUTPUT=$(node "$HOME/x1console/activatestake.js")
        send_telegram_message "$(echo -e "Restart outcome:\n\n$ACTIVATE_OUTPUT")"
       #echo -e "\nAttempting restart after activating stake..."
        #node "$HOME/x1console/restart.js"
    else
        echo -e "\nActive stake found. Attempting restart..."
        #node "$HOME/x1console/restart.js"
        RESTART_OUTPUT=$(node "$HOME/x1console/restart.js")
        send_telegram_message "$(echo -e "Restart outcome:\n\n$RESTART_OUTPUT")"
    fi
else
    echo -e "\nNo WARNING issued in health check. Exiting.\n"
    BALANCE_OUTPUT=$($HOME/x1console/epoch_balances.sh)
    sleep 3
    send_telegram_message "$(echo -e "✅ Validator Active - No action required \n\n$BALANCE_OUTPUT")"
    #send_telegram_message "✅ Validator Active - No action required \n $BALANCE_OUTPUT"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Validator status Active - No Action taken" >> "$RESTART_TIMES_LOG"
fi
