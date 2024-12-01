#!/bin/bash

# Function to read stake and vote addresses from wallets.json
get_addresses() {
    stakeholder=$(jq -r '.[] | select(.name == "Stake") | .address' wallets.json)
    voter=$(jq -r '.[] | select(.name == "Vote") | .address' wallets.json)
}

# Load addresses from wallets.json
get_addresses

# Function to display the menu
show_menu() {
    echo "Please select an option:"
    echo "1. Activate Stake"
    echo "2. Deactivate Stake"
    echo "3. Epoch Info"
    echo "4. Exit"
}

# Function to filter relevant lines from stake account output
filter_stake_info() {
    echo "$1" | grep -E 'Active Stake:|Activating Stake:|Stake activates starting from epoch:|Delegated Stake:|Active Stake:|Stake deactivates starting from epoch:'
}

# Function to pause and wait for user input
pause() {
    read -rp "Press any button to continue... " -n1
    echo -e "\n"
}

# Function to execute commands based on user input
execute_option() {
    case $1 in
        1)
            echo -e "\nActivating Stake...\n"
            output=$(solana delegate-stake "$stakeholder" "$voter")
            echo "$output"
            if echo "$output" | grep -q "Signature"; then
                echo -e "\nStake delegated successfully."
                echo "Fetching stake account info..."
                stake_info=$(solana stake-account "$stakeholder")
                echo -e "\n--- Stake Account Info ---"
                filter_stake_info "$stake_info"
            else
                echo -e "\nFailed to delegate stake."
            fi
            pause
            ;;
        2)
            echo -e "\nDeactivating Stake...\n"
            output=$(solana deactivate-stake "$stakeholder")
            echo "$output"
            if echo "$output" | grep -q "Signature"; then
                echo -e "\nStake deactivated successfully."
                echo "Fetching stake account info..."
                stake_info=$(solana stake-account "$stakeholder")
                echo -e "\n--- Stake Account Info ---"
                filter_stake_info "$stake_info"
            else
                echo -e "\nFailed to deactivate stake."
            fi
            pause
            ;;
        3)
            echo -e "\nFetching epoch info...\n"
            solana epoch-info
            pause
            ;;
        4)
            echo -e "\nExiting.\n"
            exit 0
            ;;
        *)
            echo -e "\nInvalid option. Please try again.\n"
            pause
            ;;
    esac
}

# Main loop for the menu
while true; do
    show_menu
    read -rp "Enter your choice [1-4]: " choice
    execute_option "$choice"
done
