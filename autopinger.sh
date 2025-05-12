#!/bin/bash

#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

PORT=3334

echo "Starting script execution..."

# Step 1: Check main solana balance at script start
echo "Checking main Solana balance..."
MAIN_BALANCE_OUTPUT=$(solana balance)
MAIN_BALANCE=$(echo "$MAIN_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
echo "Current Solana balance: $MAIN_BALANCE SOL"

# Check if main balance is less than 0.1
awk -v mb="$MAIN_BALANCE" 'BEGIN {exit !(mb < 0.1)}'
if [ $? -eq 0 ]; then
    echo "Balance is less than 0.1. Proceeding to check vote account..."
    # Get address
    ADDRESS=$(solana address)
    echo "Your address: $ADDRESS"
    # Get vote account balance
    VOTE_BALANCE_OUTPUT=$(solana balance ~/.config/solana/vote.json)
    VOTE_BALANCE=$(echo "$VOTE_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
    echo "Vote account balance: $VOTE_BALANCE SOL"
    # Check if vote account balance > 4
    awk -v vbal="$VOTE_BALANCE" 'BEGIN {exit !(vbal > 4)}'
    if [ $? -eq 0 ]; then
        echo "Vote account balance exceeds 4 SOL. Withdrawing 1 SOL..."
        solana withdraw-from-vote-account ~/.config/solana/vote.json "$ADDRESS" 1
        echo "Withdrawal complete."
    else
        echo "Vote account balance is 4 or less. No withdrawal needed."
    fi
else
    echo "Main balance is 0.1 or more. No need to check vote account for now."
fi

echo "Checking if port $PORT is in use..."
if lsof -i TCP:$PORT -sTCP:LISTEN -t >/dev/null; then
    echo "Port $PORT is currently in use. Exiting."
    exit 0
else
    echo "Port $PORT is free. Proceeding with further checks..."
    # Get the latest main balance again
    echo "Rechecking main Solana balance..."
    BALANCE_OUTPUT=$(solana balance)
    BALANCE=$(echo "$BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
    echo "Current Solana balance: $BALANCE SOL"

    # Compare with 0.1
    awk -v bal="$BALANCE" 'BEGIN {exit !(bal > 0.1)}'
    if [ $? -eq 0 ]; then
        echo "Balance > 0.1. Running setpinger.js..."
        node ~/x1console/setpinger.js
        echo "setpinger.js executed."
    else
        echo "Balance < 0.1. Checking address and vote account..."
        ADDRESS=$(solana address)
        echo "Your address: $ADDRESS"
        VOTE_BALANCE_OUTPUT=$(solana balance ~/.config/solana/vote.json)
        VOTE_BALANCE=$(echo "$VOTE_BALANCE_OUTPUT" | grep -oE '[0-9]*\.?[0-9]+')
        echo "Vote account balance: $VOTE_BALANCE SOL"
        awk -v vbal="$VOTE_BALANCE" 'BEGIN {exit !(vbal > 4)}'
        if [ $? -eq 0 ]; then
            echo "Vote account balance exceeds 4 SOL. Withdrawing 1 SOL..."
            solana withdraw-from-vote-account ~/.config/solana/vote.json "$ADDRESS" 1
            echo "Withdrawal complete. Running setpinger.js..."
            node ~/x1console/setpinger.js
            echo "setpinger.js executed."
        else
            echo "Vote account balance is 4 or less. No withdrawal performed."
        fi
    fi
fi

echo "Script execution finished."
