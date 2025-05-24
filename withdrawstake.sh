#!/bin/bash

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
        if [[ "$output" == *"Error"* ]]; then
            echo "Failed to retrieve details for stake account $name ($address). Skipping."
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

        printf "%-5s %-9s %-45s %-20s\n" "$index" "$name" "$address" "$unstaked_balance"
        index=$((index + 1))
    done
    echo "---------------------------------"
}

# Function to display available wallets
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

# Main process starts here

# Display stake accounts and select one
display_stake_accounts

read -p "Choose the stake account number to withdraw from (1-$(jq '. | length' allstakes.json)): " choice

stake_count=$(jq '. | length' allstakes.json)
if ! [[ "$choice" -ge 1 && "$choice" -le "$stake_count" ]]; then
    echo "Invalid stake account choice."
    exit 1
fi

stake_address=$(jq -r ".[$((choice - 1))].address" allstakes.json)
stake_name=$(jq -r ".[$((choice - 1))].name" allstakes.json)

# Retrieve stake account details
echo -e "\nRetrieving details for the selected stake account \"$stake_name\"..."
output=$(solana stake-account "$stake_address")
if [[ "$output" == *"Error"* ]]; then
    echo "Failed to retrieve details for the stake account. Please check the address."
    exit 1
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

# Select wallet to withdraw to
display_wallets

read -p "Choose the wallet number to withdraw to (1-$(jq '. | length' wallets.json) + ledger.json if exists): " wallet_choice

wallets_count=$(jq '. | length' wallets.json)
ledger_exists=false
if [ -f ledger.json ]; then
    ledger_count=$(jq '. | length' ledger.json)
    ledger_exists=true
fi

total_wallets=$wallets_count
if [ "$ledger_exists" = true ]; then
    total_wallets=$((wallets_count + ledger_count))
fi

if ! [[ "$wallet_choice" -ge 1 && "$wallet_choice" -le "$total_wallets" ]]; then
    echo "Invalid wallet choice."
    exit 1
fi

if [[ "$wallet_choice" -le "$wallets_count" ]]; then
    withdraw_to_address=$(jq -r ".[$((wallet_choice - 1))].address" wallets.json)
elif [[ "$ledger_exists" = true && "$wallet_choice" -le "$total_wallets" ]]; then
    ledger_index=$((wallet_choice - wallets_count - 1))
    if [[ "$ledger_index" -ge 0 && "$ledger_index" -lt "$ledger_count" ]]; then
        withdraw_to_address=$(jq -r ".[$ledger_index].address" ledger.json)
    else
        echo "Invalid wallet choice."
        exit 1
    fi
else
    echo "Invalid wallet choice."
    exit 1
fi

# Final step: ask for amount to withdraw
while true; do
    read -p "How much unstaked balance would you like to withdraw (0 - $unstaked_balance)? " withdraw_amount

    # Check for cancellation
    if [ -z "$withdraw_amount" ]; then
        echo "Withdrawal canceled."
        exit 0
    fi

    # Validate amount is numeric
    if ! [[ "$withdraw_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "Incorrect value entered, exiting."
        exit 1
    fi

    # Validate amount within range
    if (( $(echo "$withdraw_amount <= $unstaked_balance && $withdraw_amount >= 0" | bc -l) )); then
        # Perform the withdrawal
        solana withdraw-stake "$stake_address" "$withdraw_to_address" "$withdraw_amount"
        echo "Withdrawal of $withdraw_amount XNT from stake account \"$stake_name\" to address $withdraw_to_address completed."
        exit 0
    else
        echo "Invalid withdrawal amount. Please try again."
    fi
done
