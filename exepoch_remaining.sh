#!/bin/bash

# Extract the inside of parentheses from the Epoch Completed Time line
time_str=$(solana epoch-info | grep 'Epoch Completed Time:' | grep -oP '\(\K[^)]*')

# Initialize minutes and seconds variables
minutes=0
seconds=0

# Check if the time string contains minutes
if echo "$time_str" | grep -q 'm'; then
    # Extract minutes
    minutes=$(echo "$time_str" | grep -oP '\d+(?=m)')
    # Extract seconds
    seconds=$(echo "$time_str" | grep -oP '\d+(?=s)')
else
    # No minutes, only seconds
    seconds=$(echo "$time_str" | grep -oP '\d+(?=s)')
fi

# Ensure minutes and seconds are numbers
# If minutes is empty, set to zero
if [ -z "$minutes" ]; then
    minutes=0
fi

# Format seconds to always have two digits
formatted_seconds=$(printf "%02d" "$seconds")

# Output formatting
if [ "$minutes" -eq 0 ]; then
    echo "0m ${formatted_seconds}s remain"
else
    echo "${minutes}m ${formatted_seconds}s remain"
fi
