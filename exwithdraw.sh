#!/bin/bash

# Function to display the formatted wallet addresses with indexed options
function display_wallets() {
    echo "Available wallets:"
    echo "---------------------------------"
    printf "%-5s %-20s %-45s\n" "No" "Name" "Address"
    echo "---------------------------------"
    local index=1
    for row in $(jq -c '.[]' wallets.json); do
        name=$(echo $row | jq -r '.name')
        address=$(echo $row | jq -r '.address')
        printf "%-5s %-20s %-45s\n" "$index" "$name" "$address"
        index=$((index + 1))
    done
    echo "---------------------------------"
}

# Main menu loop
while true; do
    # Prompt the user for an action
    echo "What would you like to do?"
    echo "1. Withdraw Stake"
    echo "2. Withdraw from Vote account"
    echo "3. Exit Withdrawal"
    read -p "Please select an option (1, 2, or 3): " option

    if [[ "$option" -eq 1 ]]; then
        # Display wallets
        display_wallets

        # Ask the user which address they want to withdraw to
        read -p "Choose the wallet number to withdraw to (1-4): " choice
        withdraw_to_address=$(jq -r ".[$((choice - 1))].address" wallets.json)

        # Extract the stake address
        stake_address=$(jq -r '.[] | select(.name=="Stake") | .address' wallets.json)

        # Get the balance and active stake information
        output=$(solana stake-account "$stake_address")
        balance=$(echo "$output" | grep "Balance:" | awk '{print $2}')
        active_stake=$(echo "$output" | grep "Active Stake:" | awk '{print $3}')

        # Calculate unstaked balance
        unstaked_balance=$(bc <<< "$balance - $active_stake")
        
        # If active stake is empty, set unstaked balance to balance
        if [ -z "$active_stake" ]; then
            unstaked_balance=$balance
        fi
        
        echo "---------------------------------"
        echo "Balance: $balance"
        echo "Active Stake: $active_stake"
        echo "Unstaked Balance: $unstaked_balance"
        echo "---------------------------------"

        # Loop for withdrawal amount
        while true; do
            read -p "How much unstaked balance would you like to withdraw (0 - $unstaked_balance)?" withdraw_amount
            
            # Check if the user wants to cancel
            if [ -z "$withdraw_amount" ]; then
                echo "Withdrawal canceled."
                break
            fi
            
            # Validate the amount (must be a number)
            if ! [[ "$withdraw_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                echo "Incorrect value entered, returning to menu."
                break
            fi
            
            # Validate the amount is within the unstaked balance range
            if (( $(echo "$withdraw_amount <= $unstaked_balance" | bc -l) && $(echo "$withdraw_amount >= 0" | bc -l) )); then
                # Withdraw funds
                solana withdraw-stake "$stake_address" "$withdraw_to_address" "$withdraw_amount"
                echo "Withdrawal of $withdraw_amount SOL to $withdraw_to_address initiated."
                break
            else
                echo "Invalid withdrawal amount. Please try again."
                echo "---------------------------------"
            fi
        done

    elif [[ "$option" -eq 2 ]]; then
        # Display wallets for Vote withdrawal
        display_wallets

        # Ask the user which address they want to withdraw Vote funds to
        read -p "Choose the wallet number to withdraw Vote funds to (1-4): " choice
        withdraw_to_address=$(jq -r ".[$((choice - 1))].address" wallets.json)

        # Extract the vote address
        vote_address=$(jq -r '.[] | select(.name=="Vote") | .address' wallets.json)

        # Get the balance of the Vote account
        vote_balance_output=$(solana balance "$vote_address")
        vote_balance=$(echo "$vote_balance_output" | awk '{print $1}')
        echo "---------------------------------"
        echo "Vote Account Balance: $vote_balance SOL"
        echo "---------------------------------"

        # Prompt for withdrawal amount
        while true; do
            read -p "How much funds would you like to withdraw from the Vote account (0 - $vote_balance)?" withdraw_amount
            
            # Check if the user wants to cancel
            if [ -z "$withdraw_amount" ]; then
                echo "Withdrawal canceled."
                break
            fi
            
            # Validate the amount (must be a number)
            if ! [[ "$withdraw_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                echo "Incorrect value entered, returning to menu."
                break
            fi
            
            # Validate the amount is within the vote balance range
            if (( $(echo "$withdraw_amount <= $vote_balance" | bc -l) && $(echo "$withdraw_amount >= 0" | bc -l) )); then
                # Withdraw funds from Vote account
                solana withdraw-from-vote-account "$vote_address" "$withdraw_to_address" "$withdraw_amount"
                echo "Withdrawal of $withdraw_amount SOL from Vote account to $withdraw_to_address initiated."
                break
            else
                echo "Invalid withdrawal amount. Please try again."
                echo "---------------------------------"
            fi
        done

    elif [[ "$option" -eq 3 ]]; then
        echo "Exiting withdrawal process."
        exit 0
    else
        echo "Invalid option selected."
    fi
done
