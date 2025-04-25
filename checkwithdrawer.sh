#!/bin/bash

# Check if withdrawerconfig.json exists; create it if it doesn't
if [ ! -f "withdrawerconfig.json" ]; then
    touch withdrawerconfig.json
    # Initialize the JSON file with default value (you can change this if needed)
    echo '{ "keypairPath": "" }' > withdrawerconfig.json
fi

# Get the current keypair path from solana config
current_keypair_path=$(solana config get | grep "Keypair Path:" | awk '{print $3}')

# Read the existing keypair path from the withdrawerconfig.json
existing_keypair_path=$(jq -r '.keypairPath' withdrawerconfig.json)

# Check if current keypair path is different from existing one
if [ "$current_keypair_path" != "$existing_keypair_path" ]; then
    # Update the JSON file with the new keypair path
    jq --arg newPath "$current_keypair_path" '.keypairPath = $newPath' withdrawerconfig.json > tmp.$$.json && mv tmp.$$.json withdrawerconfig.json
fi
