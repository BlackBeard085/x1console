#!/bin/bash

# Function to pause until user presses any key
press_any_key() {
    echo -e "\nPress any key to continue..."
    # Read one character without echo
    read -n 1 -s
}

# Prompt the user for confirmation
read -p "Are you sure want to remove the scheduled update? (y/n): " answer

# Convert answer to lowercase to handle uppercase inputs
answer=${answer,,}

if [[ "$answer" == "y" ]]; then
    # Remove the files
    rm -rf update_pause_time.txt
    rm -rf update_lock.pid

    # Inform the user
    echo "Update Schedule removed, Please update your validator if required."
else
    echo "Operation cancelled."
fi

# Pause until user presses any key
press_any_key
