#!/bin/bash

# Path to your wallets.json
WALLETS_FILE="wallets.json"

# The name of the wallet you want to look up
TARGET_WALLET_NAME="Identity"

# Extract the address for the target wallet from wallets.json
ADDRESS=$(jq -r --arg name "$TARGET_WALLET_NAME" '.[] | select(.name == $name) | .address' "$WALLETS_FILE")

if [ -z "$ADDRESS" ]; then
  echo "Address for wallet '$TARGET_WALLET_NAME' not found."
  exit 1
fi

# 1. Run solana epoch-info and extract the slot number
SLOT_NUMBER=$(solana epoch-info | grep "Slot:" | awk '{print $2}')

# Print the current slot number on the same line
echo "Current Slot: $SLOT_NUMBER"

echo ""

# 2. Run solana leader-schedule and extract only the slot numbers associated with the address
# and join them with double spaces
SLOTS=$(solana leader-schedule | awk -v addr="$ADDRESS" '$0 ~ addr {printf "%s  ", $1}')

# Remove trailing whitespace
SLOTS=$(echo "$SLOTS" | sed 's/[[:space:]]*$//')

# Print the message and the slot numbers
echo "Next Scheduled Leader Slots: $SLOTS"
