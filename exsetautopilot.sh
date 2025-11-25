#!/bin/bash

# Existing cron jobs
CRON_JOB="*/30 * * * * cd ~/x1console/ && ./autopilot.sh"
CRON_JOB2="0 18 * * 1,3,6 cd ~/x1console/ && ./autostaker.sh"
CRON_JOB3="0 * * * * cd ~/x1console/ && ./autopinger.sh"
# Fourth cron job
CRON_JOB4="0 * * * * cd ~/x1console/ && ./autoupdater.sh"

# Paths
AUTOCONFIG_FILE="$HOME/x1console/autoconfig"
LOG_FILE="$HOME/x1console/restart_times.log"
UPDATER_LOG_FILE="$HOME/x1console/validator_update.log"
# Log files for staker and pinger
STAKER_LOG_FILE="$HOME/x1console/autostaker.log"
PINGER_LOG_FILE="$HOME/x1console/autopinger.log"

# Function to add all four cron jobs with duplication check
function add_cron_job {
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    # Check and add autopilot
    if echo "$crontab_content" | grep -F "$CRON_JOB" > /dev/null; then
        echo "Autopilot is already turned ON."
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Autopilot turned ON."
    fi

    # Check and add autostaker
    if echo "$crontab_content" | grep -F "$CRON_JOB2" > /dev/null; then
        echo "Auto-Staker is already turned ON."
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB2") | crontab -
        echo "Autostaker turned ON."
    fi

    # Check and add autopinger
    if echo "$crontab_content" | grep -F "$CRON_JOB3" > /dev/null; then
        echo "Auto-Pinger is already turned ON."
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB3") | crontab -
        echo "Autopinger turned ON."
    fi

    # Check and add autoupdater
    if echo "$crontab_content" | grep -F "$CRON_JOB4" > /dev/null; then
        echo "Auto-Updater is already turned ON."
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB4") | crontab -
        echo "Auto-Updater turned ON."
    fi

    echo "ON" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot, Autostaker, Autopinger, and Autoupdater turned ON.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to remove all four cron jobs
function remove_cron_job {
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)
    if echo "$crontab_content" | grep -F "$CRON_JOB" > /dev/null || \
       echo "$crontab_content" | grep -F "$CRON_JOB2" > /dev/null || \
       echo "$crontab_content" | grep -F "$CRON_JOB3" > /dev/null || \
       echo "$crontab_content" | grep -F "$CRON_JOB4" > /dev/null; then
        (crontab -l 2>/dev/null | grep -v -F "$CRON_JOB" | grep -v -F "$CRON_JOB2" | grep -v -F "$CRON_JOB3" | grep -v -F "$CRON_JOB4") | crontab -
        echo "Auto tasks turned OFF."
    else
        echo "Autopilot, Autostaker, Autopinger, and Autoupdater are already OFF."
    fi
    echo "OFF" > "$AUTOCONFIG_FILE"
    echo -e "\nAutopilot, Autostaker, Autopinger, and Autoupdater turned OFF.\n"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to turn off only autostaker (remove CRON_JOB2)
function turn_off_autostaker {
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)
    if echo "$crontab_content" | grep -F "$CRON_JOB2" > /dev/null; then
        (crontab -l 2>/dev/null | grep -v -F "$CRON_JOB2") | crontab -
        echo -e "\nAuto-Staker turned OFF."
    else
        echo -e "\nAuto-Staker is already OFF."
    fi
    echo
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to view autopilot logs
function view_autopilot_logs {
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "\nAutopilot Logs:"
        cat "$LOG_FILE"
    else
        echo "No log file found."
    fi
    echo -e "\nPress any key to exit log..."
    read -n 1 -s -r
}

# Function to view updater logs
function view_autoupdater_logs {
    if [[ -f "$UPDATER_LOG_FILE" ]]; then
        echo -e "\nAuto Updater Logs:"
        cat "$UPDATER_LOG_FILE"
    else
        echo "No updater log file found."
    fi
    echo -e "\nPress any key to exit..."
    read -n 1 -s -r
}

# New function to view autostaker logs
function view_autostaker_logs {
    if [[ -f "$STAKER_LOG_FILE" ]]; then
        echo -e "\nAutostaker Logs:"
        cat "$STAKER_LOG_FILE"
    else
        echo "No autostaker log file found."
    fi
    echo -e "\nPress any key to exit..."
    read -n 1 -s -r
}

# New function to view autopinger logs
function view_autopinger_logs {
    if [[ -f "$PINGER_LOG_FILE" ]]; then
        echo -e "\nAutopinger Logs:"
        cat "$PINGER_LOG_FILE"
    else
        echo "No autopinger log file found."
    fi
    echo -e "\nPress any key to exit..."
    read -n 1 -s -r
}

# Function to ensure config files exist
function ensure_autoconfig_file {
    mkdir -p "$(dirname "$AUTOCONFIG_FILE")"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$UPDATER_LOG_FILE")"
    mkdir -p "$(dirname "$STAKER_LOG_FILE")"
    mkdir -p "$(dirname "$PINGER_LOG_FILE")"
    [[ -f "$AUTOCONFIG_FILE" ]] || touch "$AUTOCONFIG_FILE"
    [[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"
    [[ -f "$UPDATER_LOG_FILE" ]] || touch "$UPDATER_LOG_FILE"
    [[ -f "$STAKER_LOG_FILE" ]] || touch "$STAKER_LOG_FILE"
    [[ -f "$PINGER_LOG_FILE" ]] || touch "$PINGER_LOG_FILE"
}

# Main menu
function show_menu {
    ensure_autoconfig_file
    while true; do
        echo -e "\nWhat would you like to do?"
        echo "1. Turn On All Autopilot Tasks"
        echo "2. Turn Off All Autopilot Tasks"
        echo "3. View Autopilot Logs"
        echo "4. View Auto Updater Logs"
        echo "5. View Auto Staker Logs"
        echo "6. View Auto Pinger Logs"
        echo "7. Remove Scheduled Update"
        echo "8. Turn Off Auto-staker"
        echo "9. Exit"
        echo -n "Please enter your choice (1-9): "
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
                view_autoupdater_logs
                ;;
            5)
                view_autostaker_logs
                ;;
            6)
                view_autopinger_logs
                ;;
            7)
                ./remove_update.sh
                ;;
            8)
                turn_off_autostaker
                ;;
            9)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo -e "\nInvalid choice. Please choose 1-9.\n"
                read -n 1 -s -r -p "Press any key to continue..."
                ;;
        esac
        echo ""
    done
}

# Start the menu
show_menu
