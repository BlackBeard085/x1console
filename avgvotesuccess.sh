#!/bin/bash

# Path to your wallets.json
WALLETS_FILE="wallets.json"

# Maximum credits (assumed constant)
MAX_CREDITS=8000

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

# Count total lines
LINE_COUNT=$(echo "$CREDITS_LINES" | wc -l)

if [ "$LINE_COUNT" -le 1 ]; then
  echo "0"
  exit 1
fi

# Get all lines except the first
ALL_BUT_FIRST=$(echo "$CREDITS_LINES" | sed -n '2,$p')

# Initialize sum variable
total_credits=0
count=0

# Loop through each line and sum the credits
while IFS= read -r line; do
  credits_value=$(echo "$line" | awk -F':' '{print $2}' | tr -d ' ' | awk -F'/' '{print $1}')
  # Add to total
  total_credits=$((total_credits + credits_value))
  count=$((count + 1))
done <<< "$ALL_BUT_FIRST"

# Calculate average credits
average=$(awk -v total="$total_credits" -v count="$count" 'BEGIN {printf "%.2f", total / count}')

# Calculate percentage of average
percentage=$(awk -v avg="$average" -v max="$MAX_CREDITS" 'BEGIN {printf "%.2f", (avg / max) * 100}')

echo "$percentage%"
