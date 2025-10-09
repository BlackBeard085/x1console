#!/bin/bash

# Extract the inside of parentheses from the Epoch Completed Time line
time_str=$(solana epoch-info | grep 'Epoch Completed Time:' | grep -oP '\(\K[^)]*')

# Initialize hours, minutes, and seconds variables
hours=0
minutes=0
seconds=0

# Check if the time string contains hours
if echo "$time_str" | grep -q 'h'; then
    # Extract hours
    hours=$(echo "$time_str" | grep -oP '\d+(?=h)')
fi

# Check if the time string contains minutes
if echo "$time_str" | grep -q 'm'; then
    # Extract minutes
    minutes=$(echo "$time_str" | grep -oP '\d+(?=m)')
fi

# Extract seconds (regardless of whether minutes are present)
seconds=$(echo "$time_str" | grep -oP '\d+(?=s)')

# Ensure variables are numbers
if [ -z "$hours" ]; then
    hours=0
fi
if [ -z "$minutes" ]; then
    minutes=0
fi
if [ -z "$seconds" ]; then
    seconds=0
fi

# Format each to always have two digits
formatted_hours=$(printf "%02d" "$hours")
formatted_minutes=$(printf "%02d" "$minutes")
formatted_seconds=$(printf "%02d" "$seconds")

# Output in HHh MMm SSs format
echo "${formatted_hours}h ${formatted_minutes}m ${formatted_seconds}s"
