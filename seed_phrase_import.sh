#!/bin/bash

# Define the directory for the Solana wallet
WALLET_DIR="$HOME/.config/solana"

# Create the directory if it does not exist
mkdir -p "$WALLET_DIR"

# Function to get a valid wallet name
function get_wallet_name {
    while true; do
        read -p "Enter the wallet name you wish to import (include .json): " wallet_name
        if [[ $wallet_name == *.json ]]; then
            if [[ -e "$WALLET_DIR/$wallet_name" ]]; then
                read -p "Warning: The wallet '$wallet_name' already exists. Do you want to overwrite it? (y/n): " overwrite
                if [[ $overwrite == [Yy] ]]; then
                    break
                else
                    echo "Please enter a different wallet name."
                fi
            else
                break
            fi
        else
            echo "Error: The wallet name must end with .json. Please try again."
        fi
    done
}

# Call the function to get a valid wallet name
get_wallet_name

# Extract the filename without the path for the command
wallet_filename="$wallet_name"

# Define the full path for the wallet file
wallet_file="$WALLET_DIR/$wallet_name"

# Run solana-keygen recover to recover the key and save it to the specified location
solana-keygen recover -o "$wallet_file" --force

# Provide feedback to the user
#echo "Wallet has been recovered and saved to $wallet_file."
echo -e "Press any button to continue."
read -n 1 -s  # Wait for any key press
