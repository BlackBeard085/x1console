#!/bin/bash

# Command to check active stake
STAKE_ACCOUNT_CMD="$HOME/.local/share/solana/install/active_release/bin/solana stake-account $HOME/.config/solana/stake.json"

# Get the active stake output
stake_output=$($STAKE_ACCOUNT_CMD)

# Check if the command executed successfully
if [ $? -ne 0 ]; then
    echo "Failed to retrieve stake account information."
    exit 1
fi

# Check for "Active Stake"
active_stake=$(echo "$stake_output" | grep "Active Stake:" | awk '{print $3}')  # Gets the value after "Active Stake:"

# Check if active_stake was extracted successfully
if [ -z "$active_stake" ]; then
    echo "Could not find 'Active Stake' in the output."
    exit 1
fi

# Exit if the active stake is greater than 0
if (( $(echo "$active_stake > 0" | bc -l) )); then
    echo "Stake is active: $active_stake - Please check validator status on main dashboard"
    exit 0
fi

echo "Active stake is 0, stake will activate in the next epoch, proceeding to check remaining time for current epoch..."

# Command to get the epoch info
EPOCH_INFO_CMD="$HOME/.local/share/solana/install/active_release/bin/solana epoch-info"

# Get the epoch info output
epoch_info_output=$($EPOCH_INFO_CMD)

# Check if the command executed successfully
if [ $? -ne 0 ]; then
    echo "Failed to retrieve epoch information."
    exit 1
fi

echo "Epoch Info Output:"
echo "$epoch_info_output"  # Show the complete output for debugging

# Parse the output to find 'Epoch Completed Time' line
time_remaining_line=$(echo "$epoch_info_output" | grep "Epoch Completed Time")

# Check if the line was found
if [ -z "$time_remaining_line" ]; then
    echo "Could not find the 'Epoch Completed Time' line in the output."
    exit 1
fi

# Extract the time remaining within parentheses
time_remaining=$(echo "$time_remaining_line" | grep -oP '\(\K[^)]*(?=\ remaining\))')

# Check if we successfully extracted the time remaining
if [ -z "$time_remaining" ]; then
    echo "Failed to extract the time remaining from epoch info."
    exit 1
fi

echo "Time remaining extracted: $time_remaining"

# Initialize total_seconds
total_seconds=0

# Parse the extracted time remaining
if [[ $time_remaining =~ ([0-9]+)m ]]; then
    total_seconds=$((total_seconds + ${BASH_REMATCH[1]} * 60))
fi

if [[ $time_remaining =~ ([0-9]+)s ]]; then
    total_seconds=$((total_seconds + ${BASH_REMATCH[1]}))
fi

# Check if total_seconds is greater than 200 seconds (3 minutes 20 seconds)
if [ $total_seconds -gt 200 ]; then
    echo "Time remaining is more than 3 minutes 20 seconds: $time_remaining to active stake."
    exit 0
fi

echo "Total time to sleep: $total_seconds seconds..."

# Check if total_seconds is greater than 0
if [ $total_seconds -gt 0 ]; then
    # Set an interval for updates
    interval=30
    while [ $total_seconds -gt 0 ]; do
        if [ $total_seconds -lt $interval ]; then
            sleep "$total_seconds"
            total_seconds=0
        else
            sleep "$interval"
            total_seconds=$((total_seconds - interval))
            echo "Time remaining: $total_seconds seconds to active stake..."
        fi
    done
else
    echo "Epoch has ended! Please check validator status on main dashboard"
fi

echo "Done waiting for the epoch completion! Please check validator status on main dashboard"
