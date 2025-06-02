#!/bin/bash

# Define log file path
LOG_DIR="$HOME/x1console"
LOG_FILE="$LOG_DIR/autostaker.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Check log file size and delete if larger than 50MB
if [ -f "$LOG_FILE" ]; then
    log_size=$(du -b "$LOG_FILE" | cut -f1)
    if [ "$log_size" -ge $((50 * 1024 * 1024)) ]; then
        rm "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Log file exceeded 50MB and was deleted." | tee -a "$LOG_FILE"
    fi
fi

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

# Directory containing stake files
STAKE_DIR="$HOME/.config/solana"
# Main stake file
MAIN_STAKE_FILE="$STAKE_DIR/stake.json"
# Vote account file
VOTE_ACCOUNT_FILE="$STAKE_DIR/vote.json"

# Check for existing stake*.json files
existing_files=("$STAKE_DIR"/stake*.json)
# Create any missing stake*.json files (stake1 to stake4)
for i in {1..4}; do
    filename="$STAKE_DIR/stake${i}.json"
    if ! [ -f "$filename" ]; then
        log "Creating $filename..."
        if solana-keygen new --no-passphrase -o "$filename"; then
            log "Successfully created $filename."
        else
            log "Failed to create $filename."
        fi
    else
        log "$filename already exists."
    fi
done

# Arrays to hold active stake files
active_stake_files=()

# Step 1: Check all stake accounts for active stake
for stake_file in "$STAKE_DIR"/stake*.json; do
    if [ -f "$stake_file" ]; then
        output=$(solana stake-account "$stake_file" 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Check for 'Active Stake:'
            if echo "$output" | grep -q "Active Stake:"; then
                active_stake_files+=("$stake_file")
                log "$stake_file: Active Stake found."
            fi
            # Check for 'Stake account is undelegated'
            if echo "$output" | grep -q "Stake account is undelegated"; then
                log "$stake_file: is undelegated, delegating..."
                if solana delegate-stake "$stake_file" "$VOTE_ACCOUNT_FILE"; then
                    log "Delegation of $stake_file successful."
                else
                    log "Delegation of $stake_file failed."
                fi
            fi
        else
            log "$stake_file: account needs repurposing."
        fi
    fi
done

# Step 2: Merge active stakes
if [ ${#active_stake_files[@]} -gt 0 ]; then
    for active_file in "${active_stake_files[@]}"; do
        if [ "$active_file" != "$MAIN_STAKE_FILE" ]; then
            log "Merging $active_file into $MAIN_STAKE_FILE..."
            if solana merge-stake "$MAIN_STAKE_FILE" "$active_file"; then
                log "Merged $active_file successfully."
            else
                log "Error: Failed to merge $active_file"
            fi
        else
            log "Skipping merge of $active_file with itself."
        fi
    done
    log "All active stakes have been merged."
else
    log "No active stakes found."
fi

# Step 3: Check if any stake accounts require repurposing after merging
accounts_to_repurpose=()
for stake_file in "$STAKE_DIR"/stake*.json; do
    if [ -f "$stake_file" ]; then
        output=$(solana stake-account "$stake_file" 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Check if 'Active Stake:' is missing
            if ! echo "$output" | grep -q "Active Stake:"; then
                log "$stake_file: Needs repurposing."
                accounts_to_repurpose+=("$stake_file")
            fi
            # Check if 'Stake account is undelegated' and delegate if needed
            if echo "$output" | grep -q "Stake account is undelegated"; then
                log "$stake_file: is undelegated, delegating..."
                if solana delegate-stake "$stake_file" "$VOTE_ACCOUNT_FILE"; then
                    log "Delegation of $stake_file successful."
                else
                    log "Delegation of $stake_file failed."
                fi
            fi
        else
            log "$stake_file: account needs repurposing."
            accounts_to_repurpose+=("$stake_file")
        fi
    fi
done

# If no accounts require repurposing, exit early
if [ ${#accounts_to_repurpose[@]} -eq 0 ]; then
    log "No accounts require repurposing. Exiting."
    exit 0
fi

# Step 4: Check vote account funds before withdrawal
if [ -f "$VOTE_ACCOUNT_FILE" ]; then
    log "Checking vote account details..."
    vote_output=$(solana vote-account "$VOTE_ACCOUNT_FILE" 2>/dev/null)
    if [ $? -eq 0 ]; then
        # Extract account balance
        account_balance_line=$(echo "$vote_output" | grep "Account Balance:")
        account_balance=$(echo "$account_balance_line" | awk '{print $3}' | tr -d ',')
        log "Vote account balance: $account_balance SOL"

        # Convert balance to a float for comparison
        balance_float=$(echo "$account_balance" | bc)

        # Check if balance >= 5 SOL
        if (( $(echo "$balance_float >= 5" | bc -l) )); then
            # Extract withdraw authority
            withdraw_authority_line=$(echo "$vote_output" | grep "Withdraw Authority:")
            withdraw_authority=$(echo "$withdraw_authority_line" | sed 's/^[ \t]*Withdraw Authority:[ \t]*//')
            log "Withdraw Authority: $withdraw_authority"

            # Calculate balance minus 1 SOL
            vote_balance="$account_balance"
            vote_balance_minus_one=$(echo "$vote_balance - 1" | bc)

            # Withdraw from vote account
            log "Withdrawing $vote_balance_minus_one SOL from vote account..."
            if solana withdraw-from-vote-account "$VOTE_ACCOUNT_FILE" "$withdraw_authority" "$vote_balance_minus_one"; then
                log "Withdrawal successful."
                withdrawn_amount="$vote_balance_minus_one"
            else
                log "Error: Withdrawal failed."
                exit 1
            fi
        else
            log "Vote account balance is less than 5 SOL. Skipping withdrawal."
            withdrawn_amount=0
            withdraw_authority=""
        fi
    else
        log "Failed to read vote account details."
        exit 1
    fi
else
    log "Vote account file not found: $VOTE_ACCOUNT_FILE"
    exit 1
fi

# Step 5: Create a new stake account from the first account needing repurposing
created_stake_account=""
if [ "$withdrawn_amount" != "0" ] && [ ${#accounts_to_repurpose[@]} -gt 0 ]; then
    first_account="${accounts_to_repurpose[0]}"
    log "Creating new stake account from $first_account with amount $withdrawn_amount SOL..."
    if solana create-stake-account "$first_account" "$withdrawn_amount"; then
        log "New stake account created successfully."
        created_stake_account="$first_account"
    else
        log "Failed to create new stake account."
    fi
fi

# Step 6: Delegate stake if creation was successful
if [ -n "$created_stake_account" ]; then
    log "Delegating stake for $created_stake_account to vote account..."
    if solana delegate-stake "$created_stake_account" "$VOTE_ACCOUNT_FILE"; then
        log "Delegation successful."
    else
        log "Delegation failed."
    fi
fi

log "Auto-staker execution completed."
