#!/bin/bash

# Existing cron jobs
CRON_JOB="*/30 * * * * cd ~/x1console/ && ./autopilot.sh"
CRON_JOB2="0 18 * * 1,3,6 cd ~/x1console/ && ./autostaker.sh"
# New third cron job (every hour at minute 0)
CRON_JOB3="0 * * * * cd ~/x1console/ && ./autopinger.sh"

AUTOCONFIG_FILE="$HOME/x1console/autoconfig"  # Path to your autoconfig file
LOG_FILE="$HOME/x1console/restart_times.log"  # Path to your log file

function add_cron_job {
    # Check if all three cron jobs exist
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    local missing_jobs=0

    # Check for each cron job
    if echo "$crontab_content" | grep -F "$CRON_JOB" > /dev/null; then
        :
    else
        missing_jobs=1
    fi

    if echo "$crontab_content" | grep -F "$CRON_JOB2" > /dev/null; then
        :
    else
        missing_jobs=1
    fi

    if echo "$crontab_content" | grep -F "$CRON_JOB3" > /dev/null; then
        :
    else
        missing_jobs=1
    fi

    if [ "$missing_jobs" -eq 0 ]; then
        echo "All cron jobs are already ON. No action needed."
    else
        # Append missing cron jobs
        (crontab -l 2>/dev/null; 
         echo "$CRON_JOB"
         echo "$CRON_JOB2"
         echo "$CRON_JOB3"
        ) | crontab -
        #echo "Cron jobs added."
    fi
    echo "ON" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot, Autostaker, and Autopinger turned ON.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

function remove_cron_job {
    # Remove all three cron jobs if they exist
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    # Check if any of the jobs exist
    if echo "$crontab_content" | grep -F "$CRON_JOB" > /dev/null || \
       echo "$crontab_content" | grep -F "$CRON_JOB2" > /dev/null || \
       echo "$crontab_content" | grep -F "$CRON_JOB3" > /dev/null; then
        # Remove each job
        (crontab -l 2>/dev/null | grep -v -F "$CRON_JOB" | grep -v -F "$CRON_JOB2" | grep -v -F "$CRON_JOB3") | crontab -
        echo "Cron jobs removed."
    else
        echo "Autopilot, Autostaker, and Autopinger are already OFF."
    fi
    echo "OFF" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot, Autostaker, and Autopinger turned OFF.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

function view_autopilot_logs {
    if [[ -f "$LOG_FILE" ]]; then
        #clear
        echo -e "\nAutopilot Logs:"
        cat "$LOG_FILE"
    else
        echo "No log file found."
    fi
    echo -e "\nPress any key to exit log..."
    read -n 1 -s -r
}

function ensure_autoconfig_file {
    # Ensure the directory exists
    mkdir -p "$(dirname "$AUTOCONFIG_FILE")"
    mkdir -p "$(dirname "$LOG_FILE")" # Ensure Log Directory Exists

    # Ensure the autoconfig file exists
    if [[ ! -f "$AUTOCONFIG_FILE" ]]; then
        touch "$AUTOCONFIG_FILE"
    fi

    # Ensure the log file exists
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi
}

function show_menu {
    ensure_autoconfig_file # Ensure autoconfig file exists before displaying the menu
    while true; do
        echo -e "\nWhat would you like to do?"
        echo "1. Turn On Autopilot Tasks"
        echo "2. Turn Off Autopilot Tasks"
        echo "3. View Autopilot Logs"
        echo "4. Exit"
        echo -n "Please enter your choice (1-4): "
        read -r choice
        case "$choice" in
            1)
                add_cron_job
                ;;
            2)
                remove_cron_job
                ;;
            3)
                view_autopilot_logs
                ;;
            4)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo -e "\nInvalid choice. Please choose 1, 2, 3, or 4.\n"
                read -n 1 -s -r -p "Press any key to continue..."
                ;;
        esac
        echo ""  # Print a new line for better readability
    done
}

# Start the script by showing the menu
show_menu
