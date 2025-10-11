#!/bin/bash

# Path to your wallets.json
WALLETS_FILE="wallets.json"

# Maximum credits (assumed constant as per your example)
MAX_CREDITS=3456000

# Extract the vote address from wallets.json
VOTE_ADDRESS=$(jq -r '.[] | select(.name=="Vote") | .address' "$WALLETS_FILE")

if [ -z "$VOTE_ADDRESS" ]; then
  echo "Vote address not found in $WALLETS_FILE"
  exit 1
fi

# Run the solana vote-account command
OUTPUT=$(solana vote-account "$VOTE_ADDRESS")

# Extract lines with 'credits/max credits'
CREDITS_LINES=$(echo "$OUTPUT" | grep 'credits/max credits')

# Check if at least two such lines exist
LINE_COUNT=$(echo "$CREDITS_LINES" | wc -l)

if [ "$LINE_COUNT" -lt 2 ]; then
  echo "0"
  exit 1
fi

# Get the second 'credits/max credits' line
SECOND_LINE=$(echo "$CREDITS_LINES" | sed -n '2p')

# Extract the credits number before the slash
CREDITS=$(echo "$SECOND_LINE" | awk -F':' '{print $2}' | tr -d ' ' | awk -F'/' '{print $1}')

# Calculate percentage
PERCENTAGE=$(awk -v credits="$CREDITS" -v max="$MAX_CREDITS" 'BEGIN {printf "%.2f", (credits / max) * 100}')

# Print the percentage
echo "$PERCENTAGE%"
