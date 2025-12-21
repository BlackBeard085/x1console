#!/bin/bash

# Path to the timestamp file
TIMESTAMP_FILE="update_pause_time.txt"

# Check if the file exists
if [[ ! -f "$TIMESTAMP_FILE" ]]; then
    exit 0
fi

# Read the timestamp from the file
TIMESTAMP=$(cat "$TIMESTAMP_FILE")

# Validate that the timestamp is a number
if ! [[ "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
    exit 0
fi

# Get current time in seconds since epoch
NOW=$(date +%s)

# Calculate the difference in seconds
DIFF=$((TIMESTAMP - NOW))

# Output the scheduled update time
DATE_TIME=$(date -d "@$TIMESTAMP" +"%Y-%m-%d %H:%M:%S")
echo " "
echo -n "Scheduled Update: $DATE_TIME"

# Show time left if the timestamp is in the future
if (( DIFF > 0 )); then
    echo " | Time left: $DIFF seconds"
else
    echo
fi
