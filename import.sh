#!/bin/bash

# Define the directory for the Solana wallet
WALLET_DIR="$HOME/.config/solana"

# Create the directory if it does not exist
mkdir -p "$WALLET_DIR"

# Function to get a valid wallet name
function get_wallet_name {
    while true; do
        read -p "Enter the wallet name including .json: " wallet_name
        if [[ $wallet_name == *.json ]]; then
            break
        else
            echo "Error: The wallet name must end with .json. Please try again."
        fi
    done
}

# Call the function to get a valid wallet name
get_wallet_name

# Prompt the user for the private key
read -p "Enter the private key: " private_key

# Define the full path for the wallet file
wallet_file="$WALLET_DIR/$wallet_name"

# Save the private key to the file
echo "$private_key" > "$wallet_file"

# Provide feedback to the user
echo "Private key has been saved to $wallet_file."
 echo -e "Press any button to continue."
    read -n 1 -s  # Wait for any key press
