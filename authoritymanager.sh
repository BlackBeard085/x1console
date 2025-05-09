#!/bin/bash

# Define configuration file path
CONFIG_FILE="withdrawerconfig.json"
SOLANA_CONFIG_DIR="$HOME/.config/solana"
X1CONSOLE_DIR="$HOME/x1console"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

if [ ! -f "$X1CONSOLE_DIR/ledger.json" ]; then
        echo "[]" > "$X1CONSOLE_DIR/ledger.json"  # Create an empty JSON array if the file doesn't exist
    fi
    
# Function to read and parse the withdrawer key pair path from the JSON file
get_withdrawer_keypair() {
    jq -r '.keypairPath' "$CONFIG_FILE"
}

# Function to print the current withdrawer
print_current_withdrawer() {
    local keypair_path
    keypair_path=$(get_withdrawer_keypair)
    # Replace ~ with the user's home directory if necessary
    keypair_path=${keypair_path/#\~/$HOME}
    echo -e "\nCurrent Set Withdrawer: $keypair_path\n"
}

# Function to display the wallet list and withdraw authority for normal display
display_wallets() {
    printf "%-5s %-30s %-30s\n" "No." "File Name" "Withdraw Authority"
    printf "%-5s %-30s %-30s\n" "---" "--------- " "----------------"

    # Initialize an array to hold file paths for the stake and vote wallets
    local files=()

    # Find and add all stake*.json and vote.json files to the array
    if compgen -G "$SOLANA_CONFIG_DIR/stake*.json" > /dev/null; then
        files+=("$SOLANA_CONFIG_DIR/stake*.json")
    fi

    if [ -f "$SOLANA_CONFIG_DIR/vote.json" ]; then
        files+=("$SOLANA_CONFIG_DIR/vote.json")
    fi

    # Loop through the files array and print each file's name and withdraw authority
    local index=1
    for file in "${files[@]}"; do
        for f in $file; do
            if [[ -e $f ]]; then
                local file_name
                file_name=$(basename "$f")
                local withdraw_authority=""

                # Determine if it's a stake or vote account file
                if [[ $file_name == stake*.json ]]; then
                    withdraw_authority=$(solana stake-account "$f" 2>&1)
                    if [[ $withdraw_authority == *"AccountNotFound"* ]]; then
                        withdraw_authority="no withdraw authority, requires repurposing"
                    else
                        withdraw_authority=$(echo "$withdraw_authority" | grep "Withdraw Authority:" | awk '{print $3}')
                    fi
                elif [[ $file_name == vote.json ]]; then
                    withdraw_authority=$(solana vote-account "$f" | grep "Withdraw Authority:" | awk '{print $3}')
                fi

                # Get the wallet name associated with the withdraw authority
                local wallet_name
                if [[ $withdraw_authority == "no withdraw authority, requires repurposing" ]]; then
                    wallet_name="no withdraw authority, requires repurposing"
                elif [ -n "$withdraw_authority" ]; then
                    wallet_name=$(get_wallet_name "$withdraw_authority")
                    # Check if the wallet name is empty or "Unknown"
                    if [[ "$wallet_name" == "Unknown" ]]; then
                        wallet_name="$withdraw_authority"  # Display the pubkey if no matching name is found
                    fi
                else
                    wallet_name="Unknown"
                fi

                printf "%-5s %-30s %-30s\n" "$index" "$file_name" "$wallet_name"
                index=$((index + 1))
            fi
        done
    done
}

# Function to display the wallet list and withdraw authority specifically for the Change Withdraw Authority option
display_wallets_for_change() {
    echo -e "\nCurrent Stake and Vote Wallets (excluding those needing repurposing):\n"
    printf "%-5s %-30s %-30s\n" "No." "File Name" "Withdraw Authority"
    printf "%-5s %-30s %-30s\n" "---" "--------- " "----------------"

    # Initialize an array to hold file paths for the stake and vote wallets
    local files=()

    # Find and add all stake*.json and vote.json files to the array
    if compgen -G "$SOLANA_CONFIG_DIR/stake*.json" > /dev/null; then
        files+=("$SOLANA_CONFIG_DIR/stake*.json")
    fi

    if [ -f "$SOLANA_CONFIG_DIR/vote.json" ]; then
        files+=("$SOLANA_CONFIG_DIR/vote.json")
    fi

    # Initialize an array to hold the files to be displayed
    local display_files=()
    local index=1

    # Loop through the files array and print each file's name and withdraw authority
    for file in "${files[@]}"; do
        for f in $file; do
            if [[ -e $f ]]; then
                local file_name
                file_name=$(basename "$f")
                local withdraw_authority=""

                # Determine if it's a stake or vote account file
                if [[ $file_name == stake*.json ]]; then
                    withdraw_authority=$(solana stake-account "$f" 2>&1)
                    if [[ $withdraw_authority == *"AccountNotFound"* ]]; then
                        withdraw_authority="no withdraw authority, requires repurposing"
                    else
                        withdraw_authority=$(echo "$withdraw_authority" | grep "Withdraw Authority:" | awk '{print $3}')
                    fi
                elif [[ $file_name == vote.json ]]; then
                    withdraw_authority=$(solana vote-account "$f" | grep "Withdraw Authority:" | awk '{print $3}')
                fi

                # Skip wallets that require repurposing and add to display
                if [[ $withdraw_authority != "no withdraw authority, requires repurposing" ]]; then
                    display_files+=("$f")

                    # Get the wallet name associated with the withdraw authority
                    local wallet_name
                    if [ -n "$withdraw_authority" ]; then
                        wallet_name=$(get_wallet_name "$withdraw_authority")
                        # Check if the wallet name is empty or "Unknown"
                        if [[ "$wallet_name" == "Unknown" ]]; then
                            wallet_name="$withdraw_authority"  # Display the pubkey if no matching name is found
                        fi
                    else
                        wallet_name="Unknown"
                    fi
                    printf "%-5s %-30s %-30s\n" "$index" "$file_name" "$wallet_name"
                    index=$((index + 1))
                fi
            fi
        done
    done

    # Adding the "All Wallets" option at the end
    local all_wallets_choice=$((index))
    printf "%-5s %-30s %-30s\n" "$all_wallets_choice" "All Wallets" ""
}

# Function to retrieve wallet name based on address
get_wallet_name() {
    local address="$1"
    for file in "$X1CONSOLE_DIR/wallets.json" "$X1CONSOLE_DIR/ledger.json"; do
        if [ -f "$file" ]; then
            if jq -e ".[] | select(.address == \"$address\")" "$file" > /dev/null; then
                jq -r ".[] | select(.address == \"$address\") | .name" "$file"
                return
            fi
        fi
    done
    echo "Unknown"
}

# Function to show the menu and handle user input
show_menu() {
    while true; do
        # Refresh current withdrawer
        print_current_withdrawer
        display_wallets

        echo -e "\nMenu:"
        echo "1. Change Set Withdrawer"
        echo "2. Change Withdraw Authority"
        echo "3. Exit"
        read -rp "Please select an option (1-3): " choice

        case $choice in
            1)
                changewithdrawer
                ;;
            2)
                change_withdraw_authority
                ;;
            3)
                echo "Exiting the script."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Function to execute the changewithdrawer.js script
changewithdrawer() {
    node "$X1CONSOLE_DIR/changewithdrawer.js"
    echo " "
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to add a wallet to ledger.json if it doesn't exist
add_wallet_to_ledger() {
    local new_wallet_name="$1"
    local new_wallet_pubkey="$2"

    if [ ! -f "$X1CONSOLE_DIR/ledger.json" ]; then
        echo "[]" > "$X1CONSOLE_DIR/ledger.json"  # Create an empty JSON array if the file doesn't exist
    fi

    # Use the full name with usb:// for ledger.json
    jq --arg name "$new_wallet_name" --arg address "$new_wallet_pubkey" \
       '. += [{"name": $name, "address": $address}]' "$X1CONSOLE_DIR/ledger.json" > temp.json && mv temp.json "$X1CONSOLE_DIR/ledger.json"
    echo -e "Added new withdraw authority to ledger.json: $new_wallet_name with address $new_wallet_pubkey"
}

# Function to change the Withdraw Authority
change_withdraw_authority() {
    # Display the wallets specifically for this option
    display_wallets_for_change

    echo " "
    read -rp "Which wallet would you like to change Withdraw Authority for? (Enter number): " wallet_choice

    local selected_file
    local single_choice

    # Initialize files array
    local files=()
    if compgen -G "$SOLANA_CONFIG_DIR/stake*.json" > /dev/null; then
        files+=("$SOLANA_CONFIG_DIR/stake*.json")
    fi

    if [ -f "$SOLANA_CONFIG_DIR/vote.json" ]; then
        files+=("$SOLANA_CONFIG_DIR/vote.json")
    fi

    # Build array of files to change.
    local display_files=()
    for file in "${files[@]}"; do
        for f in $file; do
            if [[ -e $f ]]; then
                local file_name=$(basename "$f")
                local withdraw_authority=""

                if [[ $file_name == stake*.json ]]; then
                    withdraw_authority=$(solana stake-account "$f" 2>&1)
                    if [[ $withdraw_authority == *"AccountNotFound"* ]]; then
                        withdraw_authority="no withdraw authority, requires repurposing"
                    else
                        withdraw_authority=$(echo "$withdraw_authority" | grep "Withdraw Authority:" | awk '{print $3}')
                    fi
                elif [[ $file_name == vote.json ]]; then
                    withdraw_authority=$(solana vote-account "$f" | grep "Withdraw Authority:" | awk '{print $3}')
                fi

                if [[ $withdraw_authority != "no withdraw authority, requires repurposing" ]]; then
                    display_files+=("$f")
                fi
            fi
        done
    done

    # Determine wallet choice
    local total_wallets=${#display_files[@]}
    if [[ "$wallet_choice" -ge 1 ]] && [[ "$wallet_choice" -le $total_wallets ]]; then
        selected_file="${display_files[$((wallet_choice - 1))]}"  # Use the filtered list
        echo -e "\nYou have chosen: $(basename "$selected_file")"
        echo "Public Key: $(solana-keygen pubkey "$selected_file")"
        single_choice=true
    elif [[ "$wallet_choice" -eq $((total_wallets + 1)) ]]; then
        echo -e "\nYou have chosen to change withdraw authority for all wallets."
        single_choice=false
    else
        echo -e "\nInvalid choice."
        return
    fi

    # Listing potential new withdraw authorities
    echo -e "\nPotential New Withdraw Authorities:"
    echo "1. $HOME/.config/solana/id.json"
    echo "2. $HOME/.config/solana/local.json"
    echo "3. usb://ledger"
    echo "4. usb://ledger?key=0"
    echo "5. usb://ledger?key=1"
    echo "6. usb://ledger?key=2"
    echo "7. usb://ledger?key=3"

    echo " "
    read -rp "Which account would you like to give the Withdraw Authority to? (Enter number): " new_authority_choice

    local new_author
    # Validate choice for new authority
    case "$new_authority_choice" in
        1) new_author="$HOME/.config/solana/id.json" ;;
        2)
            new_author="$HOME/.config/solana/local.json"
            if [ ! -f "$new_author" ]; then
                read -rp "local.json does not exist, do you wish to create a local wallet on your machine? (yes/no): " create_choice
                if [[ "$create_choice" == "yes" ]]; then
                    echo "Creating new wallet: $new_author"
                    solana-keygen new --no-passphrase -o "$new_author"
                    echo -e "\nCreated local wallet with pubkey: $(solana-keygen pubkey "$new_author")"
                elif [[ "$create_choice" == "no" ]]; then
                    echo "Reverting to menu."
                    return
                else
                    echo "Invalid choice. Please try again."
                    return
                fi
            fi
            ;;
        3) new_author="usb://ledger" ;;
        4) new_author="usb://ledger?key=0" ;;
        5) new_author="usb://ledger?key=1" ;;
        6) new_author="usb://ledger?key=2" ;;
        7) new_author="usb://ledger?key=3" ;;
        *)
            echo "Invalid choice for new withdraw authority."
            return
            ;;
    esac

    # Get the public key of the selected new authority
    local new_author_pubkey
    if [[ $new_author == "usb://ledger"* ]]; then
        new_author_pubkey=$(solana-keygen pubkey "$new_author" 2>/dev/null || echo "Could not retrieve public key")
    else
        new_author_pubkey=$(solana-keygen pubkey "$new_author")
    fi

    if [[ $new_author_pubkey == "Could not retrieve public key" ]]; then
        echo "Error retrieving public key for $new_author"
        return
    fi

    # Check if the public key exists in wallets.json
    if jq -e ".[] | select(.address == \"$new_author_pubkey\")" "$X1CONSOLE_DIR/wallets.json" > /dev/null; then
        echo "Withdraw authority exists in wallets.json: $new_author_pubkey"
    # If not found in wallets.json, check in ledger.json
    elif jq -e ".[] | select(.address == \"$new_author_pubkey\")" "$X1CONSOLE_DIR/ledger.json" > /dev/null; then
        echo "Withdraw authority exists in ledger.json: $new_author_pubkey"
    else
        # If not found in either, add it to ledger.json
        add_wallet_to_ledger "$new_author" "$new_author_pubkey"
    fi

    # Display the chosen new withdraw authority
    echo "You have chosen the new withdraw authority: $(basename "$new_author")"
    echo "Public Key: $new_author_pubkey"

    # Get the current withdrawer keypair from the config
    local current_withdraw_authority_keypair
    current_withdraw_authority_keypair=$(get_withdrawer_keypair)
    current_withdraw_authority_keypair=${current_withdraw_authority_keypair/#\~/$HOME}

    # If single wallet choice is true, only change that specific wallet's authority
    if [ "$single_choice" = true ]; then
        if [[ $selected_file == *"vote.json" ]]; then
            # Run the solana command for changing the withdraw authority
            echo -e "\nChanging withdraw authority for vote account: $wallet"
            solana vote-authorize-withdrawer "$selected_file" "$current_withdraw_authority_keypair" "$new_author"
        else
            process_wallet "$selected_file" "$new_author"
        fi
    else
        # Loop through all wallets and process each one
        for wallet in "${display_files[@]}"; do # Use the filtered display list
            if [[ $wallet == *"vote.json" ]]; then
                # Run the solana command for each vote wallet using the current withdraw authority keypair
                echo -e "\nChanging withdraw authority for vote account: $wallet"
                solana vote-authorize-withdrawer "$wallet" "$current_withdraw_authority_keypair" "$new_author"
            else
                process_wallet "$wallet" "$new_author"
            fi
        done
    fi
}

# Function to process a wallet and change withdraw authority
process_wallet() {
    local wallet_file="$1"
    local new_authority="$2"
    local file_name=$(basename "$wallet_file")
    local withdraw_authority=""

    if [[ $file_name == stake*.json ]]; then
        withdraw_authority=$(solana stake-account "$wallet_file" 2>&1)
        if [[ $withdraw_authority == *"AccountNotFound"* ]]; then
            withdraw_authority="no withdraw authority, requires repurposing"
        else
            withdraw_authority=$(echo "$withdraw_authority" | grep "Withdraw Authority:" | awk '{print $3}')
        fi
    elif [[ $file_name == vote.json ]]; then
        withdraw_authority=$(solana vote-account "$wallet_file" | grep "Withdraw Authority:" | awk '{print $3}')
    fi

    # Skip wallets that require repurposing
    if [[ $withdraw_authority == "no withdraw authority, requires repurposing" ]]; then
        echo "Skipping wallet $wallet_file (requires repurposing)"
        return
    fi

    if [[ $wallet_file == *"stake"* ]]; then
        echo -e "\nChanging withdraw authority for stake account: $wallet_file"
        solana stake-authorize "$wallet_file" --new-stake-authority "$new_authority" --new-withdraw-authority "$new_authority"
    fi
}

# Main script execution
show_menu
