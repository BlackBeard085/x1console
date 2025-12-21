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
    # Calculate days, hours, minutes, seconds
    DAYS=$((DIFF / 86400))
    HOURS=$(( (DIFF % 86400) / 3600 ))
    MINUTES=$(( (DIFF % 3600) / 60 ))
    SECONDS=$((DIFF % 60))
    
    # Build human-readable time string
    TIME_STR=""
    
    if [[ $DAYS -gt 0 ]]; then
        if [[ $DAYS -eq 1 ]]; then
            TIME_STR="${DAYS} day"
        else
            TIME_STR="${DAYS} days"
        fi
    fi
    
    if [[ $HOURS -gt 0 ]]; then
        if [[ -n "$TIME_STR" ]]; then
            TIME_STR="${TIME_STR}, "
        fi
        if [[ $HOURS -eq 1 ]]; then
            TIME_STR="${TIME_STR}${HOURS} hour"
        else
            TIME_STR="${TIME_STR}${HOURS} hours"
        fi
    fi
    
    if [[ $MINUTES -gt 0 ]]; then
        if [[ -n "$TIME_STR" ]]; then
            TIME_STR="${TIME_STR}, "
        fi
        if [[ $MINUTES -eq 1 ]]; then
            TIME_STR="${TIME_STR}${MINUTES} minute"
        else
            TIME_STR="${TIME_STR}${MINUTES} minutes"
        fi
    fi
    
    # Always show seconds if less than a day
    if [[ $DAYS -eq 0 ]]; then
        if [[ -n "$TIME_STR" ]]; then
            TIME_STR="${TIME_STR}, "
        fi
        if [[ $SECONDS -eq 1 ]]; then
            TIME_STR="${TIME_STR}${SECONDS} second"
        else
            TIME_STR="${TIME_STR}${SECONDS} seconds"
        fi
    fi
    
    echo " | Time left: $TIME_STR"
else
    echo
fi
