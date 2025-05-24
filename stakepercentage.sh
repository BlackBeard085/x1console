#!/bin/bash

# Path to your wallets.json
WALLETS_JSON="wallets.json"

# Extract the identity address from wallets.json
IDENTITY_ADDRESS=$(jq -r '.[] | select(.name=="Identity") | .address' "$WALLETS_JSON")

if [ -z "$IDENTITY_ADDRESS" ]; then
  echo "Identity address not found in $WALLETS_JSON"
  exit 1
fi

# Run the solana validators command and grep for the identity address
VALIDATOR_OUTPUT=$(solana validators | grep "$IDENTITY_ADDRESS")

if [ -z "$VALIDATOR_OUTPUT" ]; then
  echo "Validator for address $IDENTITY_ADDRESS not found."
  exit 1
fi

# Extract total stake and percentage from the output
# Example line: "   48942.441573568 SOL (0.04%)."
# We can use grep and sed/awk to parse this.
TOTAL_STAKE=$(echo "$VALIDATOR_OUTPUT" | grep -oP '\d+(\.\d+)? SOL' | head -1 | awk '{print $1}')
PERCENTAGE=$(echo "$VALIDATOR_OUTPUT" | grep -oP '\(\d+(\.\d+)?%\)' | tr -d '()')

# Format total stake to 2 decimal places
TOTAL_STAKE_FORMATTED=$(printf "%.2f" "$TOTAL_STAKE")

# Print the result
echo "$TOTAL_STAKE_FORMATTED ($PERCENTAGE)"
