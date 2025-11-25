#!/bin/bash

# Create allstakes.json if it doesn't exist
if [[ ! -f allstakes.json ]]; then
    echo "[]" > allstakes.json
fi

# Function to load vote address from wallets.json
get_vote_address() {
    local vote_address
    vote_address=$(jq -r '.[] | select(.name == "Vote") | .address' wallets.json)
    echo "$vote_address"
}

# Function to display current stake account information for all stake accounts
display_all_stake_info() {
    echo -e "\n--- Current Stake Account Info for All Stake Wallets ---"
    
    # Printing the table headers
    printf "%-11s %-18s %-17s %-15s %-12s\n" "Wallet" "Balance" "Unstaked Bal." "Active Stake" "Status"
    echo "--------------------------------------------------------------------------------"

    # List all stake wallet files in ~/.config/solana/
    stake_wallets=("$HOME/.config/solana/stake.json" "$HOME/.config/solana/stake1.json" "$HOME/.config/solana/stake2.json" "$HOME/.config/solana/stake3.json" "$HOME/.config/solana/stake4.json")

    # Create an array to hold addresses of existing wallets for updating or deletion
    existing_addresses=()

    # Clear allstakes.json temporarily
    echo "[]" > allstakes.json

    for wallet in "${stake_wallets[@]}"; do
        if [[ -f "$wallet" ]]; then
            # Get the public key for the stake account
            address=$(solana-keygen pubkey "$wallet")
            stake_info=$(solana stake-account "$address" 2>/dev/null)

            if [[ $? -eq 0 ]]; then
                balance=$(echo "$stake_info" | grep 'Balance:' | awk '{print $2}')
                active_stake=$(echo "$stake_info" | grep 'Active Stake:' | awk '{print $3}')

                # Conditional statement to handle blank active stake
                if [[ -z "$active_stake" ]]; then
                    unstaked_balance=$balance
                    active_stake="Stake Not Active"
                else
                    # Calculate Unstaked Balance
                    unstaked_balance=$(echo "$balance - $active_stake" | bc)
                fi

                # Determine Status based on stake_info content
                # Search for 'activating' and 'deactivating' (case-insensitive)
                info_lower=$(echo "$stake_info" | tr 'A-Z' 'a-z')
                if echo "$info_lower" | grep -q 'activating'; then
                    status="Activating"
                elif echo "$info_lower" | grep -q 'deactivating'; then
                    status="Deactivating"
                else
                    status=""
                fi

                # Extract wallet name from file path and capitalize first letter
                wallet_name=$(basename "$wallet" .json)
                capitalized_name=$(echo "$wallet_name" | sed 's/^\(.\)/\U\1/')

                # Printing the wallet information in formatted columns
                printf "%-11s %-18s %-17s %-15s %-12s\n" "$capitalized_name" "$balance" "$unstaked_balance" "$active_stake" "$status"
                
                # Add the address to existing addresses
                existing_addresses+=("$address")

                # Update allstakes.json with the wallet name and address
                jq --arg name "$capitalized_name" --arg address "$address" \
                '. += [{"name": $name, "address": $address}] | unique_by(.address)' allstakes.json \
                | jq 'sort_by(.name)' > tmp.$$.json && mv tmp.$$.json allstakes.json
            else
                # Suppress the actual error output
                wallet_name=$(basename "$wallet" .json)
                echo "$wallet_name - Account for repurposing."
            fi
        else
            wallet_name=$(basename "$wallet" .json)
            echo "$wallet_name doesn't exist, create it using option 4."
        fi
    done

    # Remove addresses not found in existing wallets from allstakes.json
    jq --argjson existing_addresses "$(printf '%s\n' "${existing_addresses[@]}" | jq -R . | jq -s .)" \
    'map(select(.address as $addr | $existing_addresses | index($addr)))' allstakes.json > tmp.$$.json && mv tmp.$$.json allstakes.json

    echo -e "--------------------------------------------------------------------------------\n"
}

# Function to add a new stake account
add_new_stake_account() {
    # Array of existing stake wallet filenames
    stake_wallets=("stake.json" "stake1.json" "stake2.json" "stake3.json" "stake4.json")

    # Count existing stake wallet files
    wallet_count=0
    for wallet in "${stake_wallets[@]}"; do
        if [[ -f "$HOME/.config/solana/$wallet" ]]; then
            wallet_count=$((wallet_count + 1))
        fi
    done

    # Check if the maximum limit of 5 stake wallets has been reached
    if (( wallet_count >= 5 )); then
        echo "Maximum stake wallet count reached. Please merge existing stake accounts to repurpose stake accounts"
        return
    fi

    # Check for the next available stake wallet name
    base_name="stake"
    new_name="$base_name"
    count=0

    # Search for the next available name if base name already exists
    while [[ -e "$HOME/.config/solana/$new_name.json" ]]; do
        ((count++))
        new_name="${base_name}${count}"
    done

    # Generate a new keypair and store it
    secret_key_file="$HOME/.config/solana/$new_name.json"
    solana-keygen new --no-bip39-passphrase --silent -o "$secret_key_file"

    # Get the public key of the newly created wallet
    new_address=$(solana-keygen pubkey "$secret_key_file")

    # Capitalize the first letter of the new name
    capitalized_name=$(echo "$new_name" | sed 's/^\(.\)/\U\1/')

    # Add new wallet to allstakes.json
    jq --arg name "$capitalized_name" --arg address "$new_address" \
    '. += [{"name": $name, "address": $address}] | unique_by(.address)' allstakes.json \
    | jq 'sort_by(.name)' > tmp.$$.json && mv tmp.$$.json allstakes.json

    echo "New stake account created: $capitalized_name with address $new_address"

    # Ask the user for the amount to stake
    stake_amount=""
    while true; do
        echo
        read -rp "How much XNT would you like to stake in $capitalized_name (1 - 1000000): " stake_amount

        # Validate the input
        if [[ "$stake_amount" =~ ^[0-9]+$ ]] && [ "$stake_amount" -ge 1 ] && [ "$stake_amount" -le 1000000 ]; then
            break
        else
            echo "Invalid input. Please enter a number between 1 and 1,000,000."
        fi
    done

    # Create the stake account with the specified amount
    echo "Creating stake account with $stake_amount XNT..."
    if solana create-stake-account "$secret_key_file" "$stake_amount"; then
        echo "Successfully created stake account in $capitalized_name with $stake_amount XNT staked."
        
        # Get the vote address and delegate the stake
        vote_address=$(get_vote_address)
        if [[ -n "$vote_address" ]]; then
            echo "Delegating stake to vote account: $vote_address"
            solana delegate-stake "$secret_key_file" "$vote_address"
            if [[ $? -eq 0 ]]; then
                echo "Successfully delegated stake to $vote_address."
            else
                echo "Failed to delegate stake."
            fi
        else
            echo "No valid vote address found in wallets.json."
        fi
    else
        echo "Failed to create stake account."
    fi
}

# Function to merge stake accounts
merge_stake() {
    echo -e "\n--- Merge Stake Accounts ---"

    # Load allstakes.json into an array
    stake_info=$(jq -c '.[]' allstakes.json)
    mapfile -t stake_accounts < <(echo "$stake_info")

    # Display the stake accounts in table format
    echo -e "Select a stake account to merge to:\n"
    for i in "${!stake_accounts[@]}"; do
        name=$(echo "${stake_accounts[$i]}" | jq -r '.name')
        address=$(echo "${stake_accounts[$i]}" | jq -r '.address')
        echo "$((i + 1)). $name - $address"
    done

    # User selects the account to merge to
    read -rp "Which stake account would you like to merge to (1-$((${#stake_accounts[@]}))): " merge_to_choice
    merge_to_index=$((merge_to_choice - 1))

    # Validate user input
    if [[ ! $merge_to_choice =~ ^[1-$((${#stake_accounts[@]}))]$ ]]; then
        echo "Invalid selection. Please select a number between 1 and ${#stake_accounts[@]}."
        return
    fi

    # Get the chosen merge_to account details
    merge_to_account=$(echo "${stake_accounts[$merge_to_index]}")
    merge_to_address=$(echo "$merge_to_account" | jq -r '.address')
    merge_to_name=$(echo "$merge_to_account" | jq -r '.name')

    echo -e "\nYou chose to merge to: $merge_to_name - $merge_to_address"

    # Display stake accounts again excluding the merge_to choice
    echo -e "\nSelect a stake account to merge:\n"
    for i in "${!stake_accounts[@]}"; do
        if [[ $i -ne $merge_to_index ]]; then
            name=$(echo "${stake_accounts[$i]}" | jq -r '.name')
            address=$(echo "${stake_accounts[$i]}" | jq -r '.address')
            echo "$((i + 1)). $name - $address"
        fi
    done

    # User selects the account to merge from
    read -rp "Which stake account would you like to merge from remaining options: " merging_choice
    merging_index=$((merging_choice - 1))

    # Validate user input
    if [[ ! $merging_choice =~ ^[1-$((${#stake_accounts[@]}))]$ ]] || [[ $merging_index -eq $merge_to_index ]]; then
        echo "Invalid selection. You cannot select the same account to merge from."
        return
    fi

    # Get the chosen merging account details
    merging_account=$(echo "${stake_accounts[$merging_index]}")
    merging_address=$(echo "$merging_account" | jq -r '.address')
    merging_name=$(echo "$merging_account" | jq -r '.name')

    echo -e "\nYou chose to merge from: $merging_name - $merging_address"

    # Execute the merge command
    #echo "Running command: solana merge-stake $merge_to_address $merging_address"
    echo "Merging chosen stake accounts $merge_to_address and $merging_address"

    # Run the merge command
    if solana merge-stake "$merge_to_address" "$merging_address"; then
        echo "Successfully merged $merging_name into $merge_to_name."
        echo "The $merging_name can now be repurposed as a new stake account. Please run 'Repurpose Old Stake Account'."
    else
        echo "Failed to merge stakes."
    fi
}

# Function to create a new stake account from accounts with no stake info
create_stake_account() {
    echo -e "\n--- Available Accounts To Repurpose ---"
    
    stake_wallets=("$HOME/.config/solana/stake.json" "$HOME/.config/solana/stake1.json" "$HOME/.config/solana/stake2.json" "$HOME/.config/solana/stake3.json" "$HOME/.config/solana/stake4.json")
    available_accounts=()

    for wallet in "${stake_wallets[@]}"; do
        address=$(solana-keygen pubkey "$wallet")
        stake_info=$(solana stake-account "$address" 2>/dev/null)

        # Check if there's no stake information
        if [[ $? -ne 0 ]]; then
            wallet_name=$(basename "$wallet" .json)
            capitalized_name=$(echo "$wallet_name" | sed 's/^\(.\)/\U\1/')
            echo "$(( ${#available_accounts[@]} + 1 )). $capitalized_name - $address"
            available_accounts+=("$wallet")
        fi
    done

    # Ensure we have available accounts to create from
    if [[ ${#available_accounts[@]} -eq 0 ]]; then
        echo "No available accounts to repurpose."
        return
    fi

    # User selects from available accounts by number
    read -rp "Select an account number to repurpose: " chosen_account

    # Validate user input
    chosen_index=$((chosen_account - 1))
    if [[ $chosen_index -lt 0 || $chosen_index -ge ${#available_accounts[@]} ]]; then
        echo "Invalid account number. Please select from the displayed accounts."
        return
    fi

    chosen_key_file="${available_accounts[$chosen_index]}"

    # Ask for the amount to stake
    stake_amount=""
    while true; do
        echo
        read -rp "How much XNT would you like to stake in the new account (1 - 1000000): " stake_amount

        # Validate the input
        if [[ "$stake_amount" =~ ^[0-9]+$ ]] && [ "$stake_amount" -ge 1 ] && [ "$stake_amount" -le 1000000 ]; then
            break
        else
            echo "Invalid input. Please enter a number between 1 and 1,000,000."
        fi
    done

    # Create the stake account with the specified amount using the chosen available account
    echo "Creating stake account with $stake_amount XNT using $chosen_key_file..."
    if solana create-stake-account "$chosen_key_file" "$stake_amount"; then
        echo "Successfully created a new stake account using $chosen_key_file with $stake_amount XNT staked."
        
        # Get the vote address and delegate the stake
        vote_address=$(get_vote_address)
        if [[ -n "$vote_address" ]]; then
            echo "Delegating stake to vote account: $vote_address"
            solana delegate-stake "$chosen_key_file" "$vote_address"
            if [[ $? -eq 0 ]]; then
                echo "Successfully delegated stake to $vote_address."
            else
                echo "Failed to delegate stake."
            fi
        else
            echo "No valid vote address found in wallets.json."
        fi
    else
        echo "Failed to create a new stake account."
    fi
}

# Function to activate stake for a chosen account
activate_stake() {
    echo -e "\n--- Activate Stake for Stake Accounts ---"

    # Load allstakes.json into an array
    stake_info=$(jq -c '.[]' allstakes.json)
    mapfile -t stake_accounts < <(echo "$stake_info")

    # Filter for accounts with no active stake
    active_stake_accounts=()
    for account in "${stake_accounts[@]}"; do
        address=$(echo "$account" | jq -r '.address')
        stake_info=$(solana stake-account "$address" 2>/dev/null)

        if [[ $? -eq 0 ]]; then
            active_stake=$(echo "$stake_info" | grep 'Active Stake:' | awk '{print $3}')
            if [[ -z "$active_stake" ]]; then
                active_stake_accounts+=("$account")
            fi
        fi
    done

    # Display the stake accounts that can be activated
    if [[ ${#active_stake_accounts[@]} -eq 0 ]]; then
        echo "No available stake accounts to activate."
        return
    fi

    echo -e "Select a stake account to activate:\n"
    for i in "${!active_stake_accounts[@]}"; do
        name=$(echo "${active_stake_accounts[$i]}" | jq -r '.name')
        address=$(echo "${active_stake_accounts[$i]}" | jq -r '.address')
        echo "$((i + 1)). $name - $address"
    done

    # User selects the account to activate
    read -rp "Which stake account would you like to activate (1-$((${#active_stake_accounts[@]}))): " activate_choice
    activate_index=$((activate_choice - 1))

    # Validate user input
    if [[ ! $activate_choice =~ ^[1-$((${#active_stake_accounts[@]}))]$ ]]; then
        echo "Invalid selection. Please select a valid stake account."
        return
    fi

    # Get the chosen account details
    chosen_account=$(echo "${active_stake_accounts[$activate_index]}")
    chosen_address=$(echo "$chosen_account" | jq -r '.address')

    # Get the vote address
    vote_address=$(get_vote_address)
    if [[ -z "$vote_address" ]]; then
        echo "No valid vote address found in wallets.json."
        return
    fi

    # Execute the delegate-stake command
    # echo "Running command: solana delegate-stake $chosen_address $vote_address"
    echo "delegating stake $chosen_address to vote $vote_address"
    if solana delegate-stake "$chosen_address" "$vote_address"; then
        echo -e "\nSuccessfully activated stake for $chosen_address with vote account $vote_address."
        
        # Run the stake-account command and filter the output
        #echo "Running command: solana stake-account $chosen_address"
        echo "Retrieving activation epoch."
        stake_account_info=$(solana stake-account "$chosen_address")
        
        # Print the relevant output
        echo -e "\n--- Stake Account Information ---"
        echo "$stake_account_info" | grep 'Stake activates starting from epoch:'
        echo -e "------------------------------------\n"
    else
        echo "Failed to activate stake."
    fi
}

# Function to deactivate stake for a chosen account
deactivate_stake() {
    echo -e "\n--- Deactivate Stake for Stake Accounts ---"

    # Load allstakes.json into an array
    stake_info=$(jq -c '.[]' allstakes.json)
    mapfile -t stake_accounts < <(echo "$stake_info")

    # Filter for accounts with active stake
    active_stake_accounts=()
    for account in "${stake_accounts[@]}"; do
        address=$(echo "$account" | jq -r '.address')
        stake_info=$(solana stake-account "$address" 2>/dev/null)

        if [[ $? -eq 0 ]]; then
            active_stake=$(echo "$stake_info" | grep 'Active Stake:' | awk '{print $3}')
            if [[ -n "$active_stake" ]]; then
                active_stake_accounts+=("$account")
            fi
        fi
    done

    # Display the stake accounts that can be deactivated
    if [[ ${#active_stake_accounts[@]} -eq 0 ]]; then
        echo "No available stake accounts to deactivate."
        return
    fi

    echo -e "Select a stake account to deactivate:\n"
    for i in "${!active_stake_accounts[@]}"; do
        name=$(echo "${active_stake_accounts[$i]}" | jq -r '.name')
        address=$(echo "${active_stake_accounts[$i]}" | jq -r '.address')
        echo "$((i + 1)). $name - $address"
    done

    # User selects the account to deactivate
    read -rp "Which stake account would you like to deactivate (1-$((${#active_stake_accounts[@]}))): " deactivate_choice
    deactivate_index=$((deactivate_choice - 1))

    # Validate user input
    if [[ ! $deactivate_choice =~ ^[1-$((${#active_stake_accounts[@]}))]$ ]]; then
        echo "Invalid selection. Please select a valid stake account."
        return
    fi

    # Get the chosen account details
    chosen_account=$(echo "${active_stake_accounts[$deactivate_index]}")
    chosen_address=$(echo "$chosen_account" | jq -r '.address')

    # Execute the deactivate-stake command
    #echo "Running command: solana deactivate-stake $chosen_address"
    echo "Deactivating stake $chosen_address"
    if solana deactivate-stake "$chosen_address"; then
        echo -e "\nSuccessfully deactivated stake for $chosen_address."
        
        # Run the stake-account command and filter the output
        #echo "Running command: solana stake-account $chosen_address"
        echo "Retrieving deactivation epoch"
        stake_account_info=$(solana stake-account "$chosen_address")
        
        # Print the relevant output
        echo -e "\n--- Stake Account Information ---"
        echo "$stake_account_info" | grep 'Stake deactivates starting from epoch:'
        echo -e "------------------------------------\n"
    else
        echo "Failed to deactivate stake."
    fi
}

# Function to show menu
show_menu() {
    node epoch_balances.js 2>/dev/null
    echo "Please select an option:"
    echo "1. Activate Stake"
    echo "2. Deactivate Stake"
    echo "3. Epoch Info"
    echo "4. Add New Stake Wallet"
    echo "5. Merge Stake"
    echo "6. Split Stake"
    echo "7. Repurpose Old Stake Account"
    echo "8. Autostake"
    echo "9. Withdraw Stake"
    echo "10. Exit"
}

# Function to pause
pause() {
    read -rp "Press any button to continue... " -n1
    echo -e "\n"
}

# Function to execute options
execute_option() {
    case $1 in
        1)
            activate_stake
            pause
            ;;
        2)
            deactivate_stake
            pause
            ;;
        3)
            echo -e "\nFetching epoch info...\n"
            solana epoch-info
            pause
            ;;
        4)
            add_new_stake_account
            pause
            ;;
        5)
            merge_stake
            pause
            ;;
        6)
            # Execute split stake script
            if [ -f "$HOME/x1console/splitstake.sh" ]; then
                bash "$HOME/x1console/splitstake.sh"
                if [ $? -eq 0 ]; then
                    echo -e "\n \n"
                else
                    echo -e "\nFailed to split stake.\n"
                fi
            else
                echo -e "\nsplitstake.sh does not exist. Please create it in the x1console directory.\n"
            fi
            pause
            ;;
        7)
            create_stake_account
            pause
            ;;
        8)
            ./autostaker.sh
            ;;
        9)
            ./withdrawstake.sh
            ;;
        10)
            echo -e "\nExiting.\n"
            exit 0
            ;;
        *)
            echo -e "\nInvalid option. Please try again.\n"
            pause
            ;;
    esac
}

# Main loop
while true; do
    display_all_stake_info
    show_menu
    read -rp "Enter your choice [1-10]: " choice
    execute_option "$choice"
done
