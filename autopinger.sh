#!/bin/bash

# Define log file path
LOGFILE="$HOME/x1console/autopinger.log"

# Initialize logging: create or clear log file if it exceeds 50MB
if [ -f "$LOGFILE" ]; then
    # Check size in bytes
    LOGSIZE=$(stat -c%s "$LOGFILE")
    if [ "$LOGSIZE" -gt 52428800 ]; then  # 50MB = 50*1024*1024 = 52,428,800 bytes
        rm "$LOGFILE"
        touch "$LOGFILE"
        echo "Log file exceeded 50MB and has been reset." >> "$LOGFILE"
    fi
else
    # Create log file if it doesn't exist
    touch "$LOGFILE"
fi

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

PORT=3334

log "Starting script execution..."

# Step 1: Check main solana balance at script start
log "Checking main Solana balance..."
MAIN_BALANCE_OUTPUT=$(solana balance)
log "solana balance output: $MAIN_BALANCE_OUTPUT"
MAIN_BALANCE=$(echo "$MAIN_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
log "Parsed main balance: $MAIN_BALANCE SOL"

# Check if main balance is less than 0.1
awk -v mb="$MAIN_BALANCE" 'BEGIN {exit !(mb < 0.1)}'
if [ $? -eq 0 ]; then
    log "Balance is less than 0.1. Proceeding to check vote account..."
    # Get address
    ADDRESS=$(solana address)
    log "Your address: $ADDRESS"
    # Get vote account balance
    VOTE_BALANCE_OUTPUT=$(solana balance ~/.config/solana/vote.json)
    log "Vote account balance output: $VOTE_BALANCE_OUTPUT"
    VOTE_BALANCE=$(echo "$VOTE_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
    log "Parsed vote account balance: $VOTE_BALANCE SOL"
    # Check if vote account balance > 4
    awk -v vbal="$VOTE_BALANCE" 'BEGIN {exit !(vbal > 4)}'
    if [ $? -eq 0 ]; then
        log "Vote account balance exceeds 4 SOL. Withdrawing 1 SOL..."
        solana withdraw-from-vote-account ~/.config/solana/vote.json "$ADDRESS" 1
        log "Withdrawal of 1 SOL complete."
    else
        log "Vote account balance is 4 or less. No withdrawal needed."
    fi
else
    log "Main balance is 0.1 or more. No need to check vote account for now."
fi

log "Checking if port $PORT is in use..."
if lsof -i TCP:$PORT -sTCP:LISTEN -t >/dev/null; then
    log "Port $PORT is currently in use. Exiting."
    exit 0
else
    log "Port $PORT is free. Proceeding with further checks..."
    # Get the latest main balance again
    log "Rechecking main Solana balance..."
    BALANCE_OUTPUT=$(solana balance)
    log "solana balance output: $BALANCE_OUTPUT"
    BALANCE=$(echo "$BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
    log "Parsed current balance: $BALANCE SOL"

    # Compare with 0.1
    awk -v bal="$BALANCE" 'BEGIN {exit !(bal > 0.1)}'
    if [ $? -eq 0 ]; then
        log "Balance > 0.1. Running setpinger.js..."
        node ~/x1console/setpinger.js
        log "setpinger.js executed."
    else
        log "Balance < 0.1. Checking address and vote account..."
        ADDRESS=$(solana address)
        log "Your address: $ADDRESS"
        VOTE_BALANCE_OUTPUT=$(solana balance ~/.config/solana/vote.json)
        log "Vote account balance output: $VOTE_BALANCE_OUTPUT"
        VOTE_BALANCE=$(echo "$VOTE_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
        log "Parsed vote account balance: $VOTE_BALANCE SOL"
        awk -v vbal="$VOTE_BALANCE" 'BEGIN {exit !(vbal > 4)}'
        if [ $? -eq 0 ]; then
            log "Vote account balance exceeds 4 SOL. Withdrawing 1 SOL..."
            solana withdraw-from-vote-account ~/.config/solana/vote.json "$ADDRESS" 1
            log "Withdrawal of 1 SOL complete."
            log "Running setpinger.js..."
            node ~/x1console/setpinger.js
            log "setpinger.js executed."
        else
            log "Vote account balance is 4 or less. No withdrawal performed."
        fi
    fi
fi

log "Script execution finished."
