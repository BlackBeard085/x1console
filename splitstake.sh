#!/bin/bash

# Function to get active stake accounts
get_active_stake_accounts() {
    local stake_wallets=(
        "$HOME/.config/solana/stake.json"
        "$HOME/.config/solana/stake1.json"
        "$HOME/.config/solana/stake2.json"
        "$HOME/.config/solana/stake3.json"
        "$HOME/.config/solana/stake4.json"
    )
    
    active_stake_accounts=()
    
    for wallet in "${stake_wallets[@]}"; do
        if [[ -f "$wallet" ]]; then
            address=$(solana-keygen pubkey "$wallet")
            stake_info=$(solana stake-account "$address" 2>/dev/null)

            if [[ $? -eq 0 ]]; then
                active_stake=$(echo "$stake_info" | grep 'Active Stake:' | awk '{print $3}')
                if [[ -n "$active_stake" ]]; then
                    active_stake_accounts+=("$wallet")  # Store wallet file instead of address
                fi
            fi
        fi
    done
    
    echo "${active_stake_accounts[@]}"
}

# Function to get accounts that need repurposing
get_repurposing_accounts() {
    local stake_wallets=(
        "$HOME/.config/solana/stake.json"
        "$HOME/.config/solana/stake1.json"
        "$HOME/.config/solana/stake2.json"
        "$HOME/.config/solana/stake3.json"
        "$HOME/.config/solana/stake4.json"
    )

    repurposing_accounts=()
    
    for wallet in "${stake_wallets[@]}"; do
        if [[ -f "$wallet" ]]; then
            stake_info=$(solana stake-account "$(solana-keygen pubkey "$wallet")" 2>/dev/null)

            if [[ $? -ne 0 ]]; then
                repurposing_accounts+=("$wallet")  # Store wallet file for repurposing
            fi
        fi
    done
    
    echo "${repurposing_accounts[@]}"
}

# Main script execution starts here
active_stake_accounts=($(get_active_stake_accounts))

# Check if there are active stake accounts
if [[ ${#active_stake_accounts[@]} -eq 0 ]]; then
    echo "No active stake accounts found."
    exit 1
fi

# Display active stake accounts
echo -e "\n--- Split Stakes ---"
echo -e "Choose and active stake to split\n"
for i in "${!active_stake_accounts[@]}"; do
    wallet_name=$(basename "${active_stake_accounts[$i]}" .json)  # Remove .json and extract the name
    public_key=$(solana-keygen pubkey "${active_stake_accounts[$i]}")
    echo "$((i + 1)). $wallet_name - $public_key"  # Display name and public key
done

# Ask for the user's choice
read -rp "Which stake account would you like to split? (1-${#active_stake_accounts[@]}): " choice1
if ! [[ "$choice1" =~ ^[1-9][0-9]*$ ]] || (( choice1 < 1 || choice1 > ${#active_stake_accounts[@]} )); then
    echo "Invalid selection."
    exit 1
fi

# Get the selected stake account
selected_stake_account="${active_stake_accounts[$((choice1 - 1))]}"
echo -e "\nYou have chosen: $(basename "$selected_stake_account" .json) - $(solana-keygen pubkey "$selected_stake_account")"

# Get repurposing accounts
repurposing_accounts=($(get_repurposing_accounts))

# Check if there are repurposing accounts
if [[ ${#repurposing_accounts[@]} -eq 0 ]]; then
    echo -e "\nNo accounts available to split stake with, Please merge stake to free up wallets."
    exit 1
fi

# Display repurposing accounts
echo -e "\nAvailable Accounts to split stake with:\n"
for i in "${!repurposing_accounts[@]}"; do
    wallet_name=$(basename "${repurposing_accounts[$i]}" .json)  # Remove .json and extract the name
    public_key=$(solana-keygen pubkey "${repurposing_accounts[$i]}")
    echo "$((i + 1)). $wallet_name - $public_key"  # Display name and public key
done

# Ask for the user's second choice
read -rp "Choose the account you would like to split the stake with: (1-${#repurposing_accounts[@]}): " choice2
if ! [[ "$choice2" =~ ^[1-9][0-9]*$ ]] || (( choice2 < 1 || choice2 > ${#repurposing_accounts[@]} )); then
    echo "Invalid selection."
    exit 1
fi

# Get the selected repurposing account
selected_repurposing_account="${repurposing_accounts[$((choice2 - 1))]}"
echo -e "\nYou have chosen to split with the account: $(basename "$selected_repurposing_account" .json) - $(solana-keygen pubkey "$selected_repurposing_account")"

# Check current balance of the selected stake account
balance=$(solana balance "$(solana-keygen pubkey "$selected_stake_account")")
if [[ $? -ne 0 ]]; then
    echo "Could not retrieve balance for the selected stake account."
    exit 1
fi

# Strip 'SOL' and any whitespace from balance and store it as a numerical value
numerical_balance=$(echo "$balance" | tr -d '[:space:]' | sed 's/SOL//')

# Ask how much to split
read -rp "How much would you like to split from $(solana-keygen pubkey "$selected_stake_account") (0 to $numerical_balance): " amount

# Validate the amount using bc
if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ $(echo "$amount <= 0" | bc -l) -eq 1 ]] || [[ $(echo "$amount > $numerical_balance" | bc -l) -eq 1 ]]; then
    echo "Invalid amount."
    exit 1
fi

# Confirm the split
echo -e "\nYou have chosen to split $amount from $(solana-keygen pubkey "$selected_stake_account") with $(solana-keygen pubkey "$selected_repurposing_account")."

# Execute the split command
echo -e  "\nSplitting stake account $(solana-keygen pubkey "$selected_stake_account")"
if solana split-stake "$selected_stake_account" "$selected_repurposing_account" "$amount"; then
    echo "Successfully split $amount from $(solana-keygen pubkey "$selected_stake_account") to $(solana-keygen pubkey "$selected_repurposing_account")."
    read -n 1 -s -r -p "Press any button to continue..."
else
    echo "Failed to split the stake."
fi
