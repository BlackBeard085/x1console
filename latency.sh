#!/bin/bash

# Path to your wallets.json
WALLETS_JSON="wallets.json"

# Initialize accumulators
total_credits=0
latencies=()

# Arrays for credits and max credits
credits_list=()
max_credits_list=()

# Read vote addresses into an array
mapfile -t vote_addresses < <(jq -r '.[] | select(.name=="Vote") | .address' "$WALLETS_JSON")

# Check if we have at least one vote address
if [ ${#vote_addresses[@]} -eq 0 ]; then
  echo "No vote addresses found in wallets.json."
  exit 1
fi

# Loop through each vote address
for vote in "${vote_addresses[@]}"; do
  # Get vote account info
  output=$(solana vote-account "$vote" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Failed to fetch vote account for $vote"
    continue
  fi

  # Extract total credits
  credits_line=$(echo "$output" | grep "^Credits:")
  credits=$(echo "$credits_line" | awk '{print $2}')
  total_credits=$((total_credits + credits))

  # Extract recent votes entries
  recent_votes=$(echo "$output" | awk '/Recent Tower votes \(using 31\/31 entries\):/,0' | tail -n +2)

  # Collect latencies
  while IFS= read -r line; do
    latency=$(echo "$line" | grep -o "(latency [0-9]\+)" | grep -o "[0-9]\+")
    if [ -n "$latency" ]; then
      latencies+=("$latency")
    fi
  done <<< "$recent_votes"

  # Get only the first "credits/max credits" line
  credits_max_line=$(echo "$output" | grep "credits/max credits:" | head -n 1)
  if [ -n "$credits_max_line" ]; then
    # Extract current credits
    c=$(echo "$credits_max_line" | grep -oP "credits/max credits:\s*\K[0-9]+")
    credits_list+=("$c")
  fi

  # Compute max credits from 'solana epoch-info'
  epoch_info=$(solana epoch-info 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Failed to fetch epoch info."
    continue
  fi

  # Extract 'Epoch Completed Slots:'
  slots_line=$(echo "$epoch_info" | grep "Epoch Completed Slots:")
  if [ -n "$slots_line" ]; then
    numerator=$(echo "$slots_line" | grep -oP "Epoch Completed Slots:\s*\K[0-9]+")
    # Calculate max credits
    max_credits=$((numerator * 16))
    max_credits_list+=("$max_credits")
  fi
done

# Calculate average latency of last 31 entries
count=${#latencies[@]}
if [ "$count" -gt 0 ]; then
  start_index=$((count - 31))
  if [ "$start_index" -lt 0 ]; then start_index=0; fi
  sum=0
  for ((i=start_index; i< count; i++)); do
    sum=$((sum + latencies[i]))
  done
  avg_latency=$(echo "scale=2; $sum / ( $count - $start_index )" | bc)
else
  avg_latency="N/A"
fi

# Assume only one reading, so take the first element if exists
if [ ${#credits_list[@]} -gt 0 ]; then
  current_credits="${credits_list[0]}"
else
  current_credits=0
fi

if [ ${#max_credits_list[@]} -gt 0 ]; then
  current_max_credits="${max_credits_list[0]}"
else
  current_max_credits=1  # avoid division by zero
fi

# Calculate percentage
percentage=$(echo "scale=2; ($current_credits / $current_max_credits) * 100" | bc)

# Output total credits, current credits/max credits with percentage, and average latency
echo "T.Credits:$total_credits    C.Credits: ${current_credits}/${current_max_credits} (${percentage}%)    Avg Latency:$avg_latency"
