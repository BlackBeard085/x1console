#!/bin/bash

# Set the directory containing the JSON files
WALLET_DIR="$HOME/.config/solana"

# Check if the directory exists
if [ ! -d "$WALLET_DIR" ]; then
    echo "The directory $WALLET_DIR does not exist. Creating it now."
    mkdir -p "$WALLET_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to create directory $WALLET_DIR."
        exit 1
    fi
fi

# Function to display current wallets with their public addresses
current_available_wallets() {
    echo -e "\nCurrent wallets in .config/solana directory:"
    files=("$WALLET_DIR"/*.json)  # Gather wallet files

    if [ ${#files[@]} -eq 0 ]; then
        echo "No wallet files found in $WALLET_DIR."
    else
        # Print table header
        printf "%-30s | %s\n" "Wallet Name" "Public Address"
        printf "%-30s | %s\n" "-------------" "--------------"

        for file in "${files[@]}"; do
            wallet_name=$(basename "$file")
            public_address=$(solana-keygen pubkey "$file")  # Retrieve public address
            printf "%-30s | %s\n" "$wallet_name" "$public_address"
        done
    fi
    echo " "
    echo -e "Press any button to continue."
    read -n 1 -s  # Wait for any key press
}

# Function to add a new wallet
add_new_wallet() {
    echo -e "\nNOTE: Replacing the stake.json or vote.json will cause the public keys to update in the wallets.json file."
    read -p "Please name the new wallet file you wish to create (including .json): " new_wallet_name
    
    if [[ "$new_wallet_name" =~ \.json$ ]]; then  # Ensure the name ends with .json
        echo -e "\nCreating new wallet..."
        solana-keygen new --no-passphrase -o "$WALLET_DIR/$new_wallet_name"
        echo -e "\nNew wallet file '$new_wallet_name' created successfully.\n"
        read -n 1 -s  # Wait for any key press
    else
        echo "Error: The file name must end with .json."
    fi
}

# Function to remove a wallet
remove_wallet() {
    echo -e "\nPlease make sure you have a backup of your wallets before removing them."
    read -p "Do you wish to continue? (y/n): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        read -p "Enter the name of the wallet you wish to remove (including .json): " wallet_to_remove

        # Check if the file exists
        if [[ -f "$WALLET_DIR/$wallet_to_remove" ]]; then
            read -p "Are you sure you want to remove '$wallet_to_remove'? (y/n): " confirm_remove

            if [[ "$confirm_remove" == "y" || "$confirm_remove" == "Y" ]]; then
                rm -rf "$WALLET_DIR/$wallet_to_remove"
                echo -e "\nWallet '$wallet_to_remove' has been removed successfully.\n"
                read -n 1 -s  # Wait for any key press
            else
                echo -e "Operation cancelled. Wallet was not removed.\n"
            fi
        else
            echo -e "Error: Wallet '$wallet_to_remove' does not exist in $WALLET_DIR.\n"
        fi
    else
        echo -e "Operation cancelled.\n"
    fi
}

while true; do
    # Display options to the user
    echo -e "\nChoose an option:"
    echo "1. Back up a specific wallet"
    echo "2. Back up all wallets"
    echo "3. Current available wallets"
    echo "4. Add New Wallet"
    echo "5. Import Wallet using Private Key"
    echo "6. Import Wallet using Seed Phrase"
    echo "7. Remove Wallet"
    echo "8. Exit"
    read -p "Enter your choice (1-8): " choice

    # Always gather wallet files before the options
    files=("$WALLET_DIR"/*.json)

    case $choice in
        1)  # Back up a specific wallet
            echo -e "\nAvailable wallets:"
            for i in "${!files[@]}"; do
                echo "$((i + 1)). $(basename "${files[i]}")"
            done

            read -p "Enter the number corresponding to the wallet you would like to back up: " wallet_number

            # Validate the input number
            if [[ $wallet_number =~ ^[0-9]+$ ]] && [ "$wallet_number" -gt 0 ] && [ "$wallet_number" -le "${#files[@]}" ]; then
                selected_wallet="${files[$((wallet_number - 1))]}"

                echo -e "\nYou have chosen $(basename "$selected_wallet"). This will show the private key for $(basename "$selected_wallet")."
                read -p "Do you wish to continue? (y/n) " confirm

                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    echo -e "\nDisplaying private key for $(basename "$selected_wallet")..."
                    cat "$selected_wallet"
                    echo " "
                    echo -e "\nPlease backup your keys locally. Press any button to continue."
                    read -n 1 -s  # Wait for any key press
                else
                    echo -e "\nOperation cancelled."
                fi
            else
                echo -e "\nError: Invalid selection."
            fi
            ;;
        
        2)  # Back up all wallets
            echo -e "\nYou have chosen to back up all wallets. This will show the private keys for all your wallets."
            if [ ${#files[@]} -eq 0 ]; then
                echo -e "\nNo wallet files found in $WALLET_DIR."
                read -p "Press any button to continue."
            else
                read -p "Do you wish to continue? (y/n) " confirm

                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    echo -e "\nDisplaying private keys for all wallets..."
                    for file in "${files[@]}"; do
                        echo -e "\n----- Private Key for $(basename "$file") -----"
                        cat "$file"
                        echo " "
                        echo "----------------------------------------"
                    done
                    echo -e "\nPlease backup your keys locally. Press any button to continue."
                    read -n 1 -s  # Wait for any key press
                else
                    echo -e "\nOperation cancelled."
                fi
            fi
            ;;
        
        3)  # Display current available wallets
            current_available_wallets
            ;;
        
        4)  # Add New Wallet
            add_new_wallet
            ;;
        5)
            ./import.sh
            ;;
        6)
            ./seed_phrase_import.sh
            ;;
        7)  # Remove Wallet
            remove_wallet
            ;;
        
        8) # Exit the script
             echo -e "\nExiting the script."
             exit 0
            ;;
        
        *)  # Invalid option
            echo -e "\nInvalid option, please choose 1, 2, 3, 4, 5, or 6."
            ;;
    esac
done

echo -e "\nBackup completed."
