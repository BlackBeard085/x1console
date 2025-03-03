#!/bin/bash

CRON_JOB="*/30 * * * * cd ~/x1console/ && ./autopilot.sh"  # Example cron job
AUTOCONFIG_FILE="$HOME/x1console/autoconfig"  # Path to your autoconfig file

function add_cron_job {
    # Check if the cron job already exists
    if crontab -l | grep -qF "$CRON_JOB"; then
        # Cron job already exists, update autoconfig
        echo "Autopilot already ON. No action needed."
    else
        # Add the cron job
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        #echo "Cron job added: $CRON_JOB"
    fi
    echo "ON" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot turned ON.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

function remove_cron_job {
    # Remove duplicates from the cron jobs
    if crontab -l | grep -qF "$CRON_JOB"; then
        crontab -l | grep -v -F "$CRON_JOB" | crontab -
        #echo "Cron job removed: $CRON_JOB"
    else
        echo "Autopilot is already OFF "
    fi
    echo "OFF" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot turned OFF.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

function ensure_autoconfig_file {
    # Ensure the directory exists
    mkdir -p "$(dirname "$AUTOCONFIG_FILE")"

    # Ensure the autoconfig file exists
    if [[ ! -f "$AUTOCONFIG_FILE" ]]; then
        touch "$AUTOCONFIG_FILE"
    fi
}

function show_menu {
    ensure_autoconfig_file # Ensure autoconfig file exists before displaying the menu
    while true; do
        echo -e "\nWhat would you like to do?"
        echo "1. Turn On Autopilot"
        echo "2. Turn Off Autopilot"
        echo "3. Exit"
        echo -n "Please enter your choice (1-3): "
        read -r choice
        case "$choice" in
            1)
                add_cron_job
                ;;
            2)
                remove_cron_job
                ;;
            3)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo -e "\nInvalid choice. Please choose 1, 2, or 3.\n"
                read -n 1 -s -r -p "Press any key to continue..."
                ;;
        esac
        echo ""  # Print a new line for better readability
    done
}

# Start the script by showing the menu
show_menu
