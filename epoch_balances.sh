#!/bin/bash

# Function to get balance for a given address
get_balance() {
    local address=$1
    solana balance "$address" | awk '{print $1}'
}

# Function to get total active stake for a vote address
get_total_stake() {
    local vote_addr=$1
    local sum=0
    # Run stakes command and parse all "Active Stake:" lines
    stakes_output=$(solana stakes "$vote_addr")
    # Sum all Active Stake amounts
    sum=$(echo "$stakes_output" | grep "Active Stake:" | awk '{sum += $3} END {printf "%.2f", sum}')
    echo "$sum"
}

# Function to get total self delegated stake from all stake accounts
get_total_self_delegated() {
    local total_self=0
    # Read all stake addresses from allstakes.json
    addresses=$(jq -r '.[] | select(.name=="Stake" or .name=="Stake1") | .address' allstakes.json)
    for addr in $addresses; do
        # For each stake account, get "Active Stake" amount
        stake_output=$(solana stake-account "$addr" 2>/dev/null)
        active_stake_line=$(echo "$stake_output" | grep "Active Stake:")
        if [ -n "$active_stake_line" ]; then
            # Extract the active stake amount
            amount=$(echo "$active_stake_line" | awk '{print $3}')
            # Sum up
            total_self=$(awk "BEGIN {print $total_self + $amount}")
        fi
    done
    echo "$total_self"
}

# Function to get total unstaked balance by summing 'Balance' from all stake accounts
get_total_unstaked_balance() {
    local total_balance=0
    # Read all stake addresses from allstakes.json
    addresses=$(jq -r '.[] | select(.name=="Stake" or .name=="Stake1") | .address' allstakes.json)
    for addr in $addresses; do
        # For each stake account, get "Balance" amount
        stake_output=$(solana stake-account "$addr" 2>/dev/null)
        balance_line=$(echo "$stake_output" | grep "Balance:")
        if [ -n "$balance_line" ]; then
            # Extract the balance amount
            amount=$(echo "$balance_line" | awk '{print $2}')
            # Sum up
            total_balance=$(awk "BEGIN {print $total_balance + $amount}")
        fi
    done
    # Compute unstaked balance as total balance minus total self delegated stake
    total_self=$(get_total_self_delegated)
    unstaked=$(awk "BEGIN {print $total_balance - $total_self}")
    echo "$unstaked"
}

# Read wallet addresses from wallets.json
id_address=$(jq -r '.[] | select(.name=="Id") | .address' wallets.json)
identity_address=$(jq -r '.[] | select(.name=="Identity") | .address' wallets.json)
vote_address=$(jq -r '.[] | select(.name=="Vote") | .address' wallets.json)

# Run solana epoch-info
output=$(solana epoch-info)
epoch=$(echo "$output" | grep "Epoch:" | awk '{print $2}')
remaining_time=$(echo "$output" | grep "Epoch Completed Time:" | sed -E 's/.*\(([^)]+)\).*/\1/')

# Get balances
id_balance=$(get_balance "$id_address")
identity_balance=$(get_balance "$identity_address")
vote_balance=$(get_balance "$vote_address")

# Calculate total active stake
total_stake=$(get_total_stake "$vote_address")
# Calculate total self delegated stake
total_self_delegated=$(get_total_self_delegated)
# Calculate delegated stake
delegated_stake=$(awk "BEGIN {printf \"%.2f\", $total_stake - $total_self_delegated}")

# Calculate total unstaked balance
total_unstaked=$(get_total_unstaked_balance)

# Format total stake and delegated stake for display
# (formatted as per request)
# Output
echo -e "Total Stake: $total_stake | Delegated Stake: $delegated_stake | Self Stake: $total_self_delegated"
#echo "Total Unstaked Balance: $total_unstaked"
echo "Epoch: $epoch | Remaining Time: $remaining_time"
echo ""
echo "Balances:"
echo "Id: $id_balance  |  Identity: $identity_balance  |  Vote: $vote_balance"
echo "Total Unstaked Balance: $total_unstaked"
echo ""
