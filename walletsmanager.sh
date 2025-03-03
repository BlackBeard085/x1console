#!/bin/bash

# Set the directory containing the JSON files
WALLET_DIR="$HOME/.config/solana"

# Check if the directory exists
if [ ! -d "$WALLET_DIR" ]; then
    echo "The directory $WALLET_DIR does not exist."
    exit 1
fi

while true; do
    # Display options to the user
    echo -e "\nChoose an option:"
    echo "1. Back up a specific wallet"
    echo "2. Back up all wallets"
    echo "3. Exit"
    read -p "Enter your choice (1/2/3): " choice

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
        
        3)  # Exit the script
            echo -e "\nExiting the script."
            exit 0
            ;;
        
        *)  # Invalid option
            echo -e "\nInvalid option, please choose 1, 2, or 3."
            ;;
    esac
done

echo -e "\nBackup completed."
