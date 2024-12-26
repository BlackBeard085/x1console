#!/bin/bash

LOG_DIRECTORY="$HOME/x1"
LOG_FILE="log.txt"
VALIDATOR_DIR="$HOME/x1/"

# Function to wait for user input before returning to menu
function pause_and_return {
    echo -e "\nPress any key to return to the menu...\n"
    read -n 1 -s
    main_menu
}

# Function to stop the validator
function stop_validator {
    echo 

    if lsof -i:8899 &>/dev/null; then
        echo "Stopping validator..."
        (cd "$VALIDATOR_DIR" && solana-validator exit -f)
        
        if [ $? -eq 0 ]; then
            echo "Validator stopped successfully."
        else
            echo "Error stopping validator."
        fi
    else
        echo "Validator is not running (port 8899 is not in use)."
    fi

    pause_and_return
}

# Function to show logs
function show_logs {
    echo 
    
    echo "Showing logs (press any key to exit)..."
    
    # Run the tail command in the background
    tail -f "$LOG_DIRECTORY/$LOG_FILE" &
    TAIL_PID=$!

    # Wait for user input to cancel
    read -n 1 -s
    echo -e "\nExiting log viewer...\n"
    
    # Kill the tail process
    kill $TAIL_PID
    wait $TAIL_PID 2>/dev/null

    pause_and_return
}

# Function to delete logs
function delete_logs {
    echo 

    if lsof -i:8899 &>/dev/null; then
        read -p "The validator is currently running and must be turned off to delete validator logs. Do you wish to continue? (yes/no) " user_choice
        
        if [[ "$user_choice" == "yes" ]]; then
            stop_validator
        else
            echo -e "\nOperation canceled. Returning to the main menu.\n"
            pause_and_return
        fi
    fi
    
    rm -rf "$LOG_DIRECTORY/$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "\nValidator logs have been deleted.\n"
    else
        echo -e "\nError deleting logs.\n"
    fi

    pause_and_return
}

# Main menu function
function main_menu {
    echo -e "\nChoose an option:\n"
    echo "1. Stop Validator"
    echo "2. Show Logs"
    echo "3. Delete Logs"
    echo "4. Exit"
    
    echo
    read -n 1 -s option
    echo  # Adding a new line after option selection for readability

    case $option in
        1)
            stop_validator
            ;;
        2)
            show_logs
            ;;
        3)
            delete_logs
            ;;
        4)
            echo -e "\nExiting...\n"
            exit 0
            ;;
        *)
            echo -e "\nInvalid option. Try again.\n"
            pause_and_return
            ;;
    esac
}

# Start the main menu
main_menu
