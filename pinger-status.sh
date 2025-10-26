#!/bin/bash

# Fetch the ping times data
output=$(curl -s http://localhost:3334/ping_times | jq '.')

# Check if the output contains the "pingTimes" array
if echo "$output" | jq -e '.pingTimes' > /dev/null 2>&1; then
    echo "Pinger: Active"
else
    echo "Pinger: Inactive"
fi
