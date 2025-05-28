#!/bin/bash

# Function to display the formatted wallet addresses with indexed options
function display_wallets() {
    echo -e "\nAvailable wallets:"
    echo "---------------------------------"
    printf "%-5s %-15s %-45s\n" "No" "Name" "Address"
    echo "---------------------------------"
    local index=1

    # Display wallets from wallets.json
    for row in $(jq -c '.[]' wallets.json); do
        name=$(echo "$row" | jq -r '.name')
        address=$(echo "$row" | jq -r '.address')
        printf "%-5s %-15s %-45s\n" "$index" "$name" "$address"
        index=$((index + 1))
    done

    # Display wallets from ledger.json if it exists
    if [ -f ledger.json ]; then
        for row in $(jq -c '.[]' ledger.json); do
            full_name=$(echo "$row" | jq -r '.name')
            name=${full_name##*/}
            address=$(echo "$row" | jq -r '.address')
            printf "%-5s %-15s %-45s\n" "$index" "$name" "$address"
            index=$((index + 1))
        done
    fi

    echo "---------------------------------"
}

# Function to display available stake accounts
function display_stake_accounts() {
    echo -e "\nAvailable Stake Accounts:"
    echo "---------------------------------"
    printf "%-5s %-9s %-45s %-20s\n" "No" "Name" "Address" "Unstaked Balance"
    echo "---------------------------------"
    
    local index=1
    for row in $(jq -c '.[]' allstakes.json); do
        name=$(echo "$row" | jq -r '.name')
        address=$(echo "$row" | jq -r '.address')
        
        output=$(solana stake-account "$address")
        balance=$(echo "$output" | grep "Balance:" | awk '{print $2}')
        active_stake=$(echo "$output" | grep "Active Stake:" | awk '{print $3}')

        balance=$(printf "%.8f" "$balance")
        active_stake=$(printf "%.8f" "$active_stake")

        if [[ -z "$active_stake" || "$active_stake" == "0" ]]; then
            unstaked_balance="$balance"
        else
            unstaked_balance=$(echo "$balance - $active_stake" | bc)
        fi

        if [[ "$unstaked_balance" == .* ]]; then
            unstaked_balance="0$unstaked_balance"
        fi

        printf "%-5s %-9s %-45s %-20s\n" "$index" "$name" "$address" "$unstaked_balance"
        index=$((index + 1))
    done
    echo "---------------------------------"
}

# Function to withdraw from Identity
function withdraw_from_identity() {
    echo -e "\nWithdraw from Identity:"
    
    # Display wallets to withdraw to
    display_wallets

    # Ask the user which wallet they want to withdraw to
    read -p "Choose the wallet number to withdraw to: " wallet_choice
    
    wallets_count=$(jq '. | length' wallets.json)
    if [[ "$wallet_choice" -le "$wallets_count" ]]; then
        withdraw_to_address=$(jq -r ".[$((wallet_choice - 1))].address" wallets.json)
    elif [ -f ledger.json ]; then
        ledger_index=$((wallet_choice - wallets_count - 1))
        withdraw_to_address=$(jq -r ".[$ledger_index].address" ledger.json)
    else
        echo "Invalid wallet choice."
        return
    fi

    # Get the balance of the Identity account
    identity_balance_output=$(solana balance ~/.config/solana/identity.json)
    identity_balance=$(echo "$identity_balance_output" | awk '{print $1}')
    echo "---------------------------------"
    echo "Identity Account Balance: $identity_balance XNT"
    echo "---------------------------------"

    # Prompt for withdrawal amount
    while true; do
        read -p "How much funds would you like to withdraw from the Identity account (0 - $identity_balance)? " withdraw_amount
        
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
        
        # Validate the amount is within the identity balance range
        if (( $(echo "$withdraw_amount <= $identity_balance && $withdraw_amount >= 0" | bc -l) )); then
            # Withdraw funds from Identity account
            solana transfer --from ~/.config/solana/identity.json "$withdraw_to_address" "$withdraw_amount"
            echo "Withdrawn $withdraw_amount XNT from Identity account to $withdraw_to_address."
            break
        else
            echo "Invalid withdrawal amount. Please try again."
            echo "---------------------------------"
        fi
    done
}

# Main menu loop
while true; do
    ./epoch_balances.sh
    echo "What would you like to do?"
    echo "1. Withdraw Stake"
    echo "2. Withdraw from Vote account"
    echo "3. Withdraw from Identity"
    echo -e "4. Exit Withdrawal\n"
    read -p "Please select an option (1-4): " option

    if [[ "$option" -eq 1 ]]; then
        # Display available stake accounts
        display_stake_accounts

        read -p "Choose the stake account number to withdraw from (1-5): " choice
        
        stake_address=$(jq -r ".[$((choice - 1))].address" allstakes.json)
        stake_name=$(jq -r ".[$((choice - 1))].name" allstakes.json)

        display_wallets
        
        read -p "Choose the wallet number to withdraw to: " wallet_choice
        
        wallets_count=$(jq '. | length' wallets.json)
        if [[ "$wallet_choice" -le "$wallets_count" ]]; then
            withdraw_to_address=$(jq -r ".[$((wallet_choice - 1))].address" wallets.json)
        else
           if [ -f ledger.json ]; then
                ledger_count=$(jq '. | length' ledger.json)
                ledger_index=$((wallet_choice - wallets_count - 1))
                if [[ "$ledger_index" -ge 0 && "$ledger_index" -lt "$ledger_count" ]]; then
                    withdraw_to_address=$(jq -r ".[$ledger_index].address" ledger.json)
                else
                    echo "Invalid wallet choice."
                    continue
                fi
            else
                echo "Invalid wallet choice."
                continue
            fi
        fi

        echo -e "\nRetrieving details for the selected stake account \"$stake_name\"..."
        output=$(solana stake-account "$stake_address")
        
        if [[ "$output" == *"Error"* ]]; then
            echo "Failed to retrieve details for the stake account. Please check the address."
            continue
        fi
        
        balance=$(echo "$output" | grep "Balance:" | awk '{print $2}')
        active_stake=$(echo "$output" | grep "Active Stake:" | awk '{print $3}')

        balance=$(printf "%.8f" "$balance")
        active_stake=$(printf "%.8f" "$active_stake")

        if [[ -z "$active_stake" || "$active_stake" == "0" ]]; then
            unstaked_balance="$balance"
        else
            unstaked_balance=$(echo "$balance - $active_stake" | bc)
        fi
        
        if [[ "$unstaked_balance" == .* ]]; then
            unstaked_balance="0$unstaked_balance"
        fi

        echo "---------------------------------"
        echo "Stake Account Name: $stake_name"
        echo "Address: $stake_address"
        echo "Balance: $balance"
        echo "Active Stake: $active_stake"
        echo "Unstaked Balance: $unstaked_balance"
        echo "---------------------------------"

        while true; do
            read -p "How much unstaked balance would you like to withdraw (0 - $unstaked_balance)? " withdraw_amount
            
            if [ -z "$withdraw_amount" ]; then
                echo "Withdrawal canceled."
                break
            fi
            
            if ! [[ "$withdraw_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                echo "Incorrect value entered, returning to menu."
                break
            fi
            
            if (( $(echo "$withdraw_amount <= $unstaked_balance && $withdraw_amount >= 0" | bc -l) )); then
                solana withdraw-stake "$stake_address" "$withdraw_to_address" "$withdraw_amount"
                echo "Withdrawn $withdraw_amount XNT to $withdraw_to_address."
                break
            else
                echo "Invalid withdrawal amount. Please try again."
                echo "---------------------------------"
            fi
        done

    elif [[ "$option" -eq 2 ]]; then
        # Withdraw from Vote account
        echo -e "\nWithdraw from Vote Account:"
        display_wallets

        read -p "Choose the wallet number to withdraw Vote funds to: " wallet_choice
        
        wallets_count=$(jq '. | length' wallets.json)
        if [[ "$wallet_choice" -le "$wallets_count" ]]; then
            withdraw_to_address=$(jq -r ".[$((wallet_choice - 1))].address" wallets.json)
        else
           if [ -f ledger.json ]; then
                ledger_count=$(jq '. | length' ledger.json)
                ledger_index=$((wallet_choice - wallets_count - 1))
                if [[ "$ledger_index" -ge 0 && "$ledger_index" -lt "$ledger_count" ]]; then
                    withdraw_to_address=$(jq -r ".[$ledger_index].address" ledger.json)
                else
                    echo "Invalid wallet choice."
                    continue
                fi
            else
                echo "Invalid wallet choice."
                continue
            fi
        fi

        vote_address=$(jq -r '.[] | select(.name=="Vote") | .address' wallets.json)

        vote_balance_output=$(solana balance "$vote_address")
        vote_balance=$(echo "$vote_balance_output" | awk '{print $1}')
        echo "---------------------------------"
        echo "Vote Account Balance: $vote_balance XNT"
        echo "---------------------------------"

        while true; do
            read -p "How much funds would you like to withdraw from the Vote account (0 - $vote_balance)? " withdraw_amount
            
            if [ -z "$withdraw_amount" ]; then
                echo "Withdrawal canceled."
                break
            fi
            
            if ! [[ "$withdraw_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                echo "Incorrect value entered, returning to menu."
                break
            fi
            
            if (( $(echo "$withdraw_amount <= $vote_balance && $withdraw_amount >= 0" | bc -l) )); then
                solana withdraw-from-vote-account "$vote_address" "$withdraw_to_address" "$withdraw_amount"
                echo "Withdrawn $withdraw_amount XNT from Vote account to $withdraw_to_address."
                break
            else
                echo "Invalid withdrawal amount. Please try again."
                echo "---------------------------------"
            fi
        done

    elif [[ "$option" -eq 3 ]]; then
        # Withdraw from Identity account
        withdraw_from_identity

    elif [[ "$option" -eq 4 ]]; then
        echo "Exiting withdrawal process."
        exit 0
    else
        echo "Invalid option selected."
    fi
done
