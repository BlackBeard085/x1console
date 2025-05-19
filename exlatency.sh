#!/bin/bash

# Path to your wallets.json
WALLETS_JSON="wallets.json"

# Initialize accumulators
total_credits=0
latencies=()

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

  # Extract credits
  credits_line=$(echo "$output" | grep "^Credits:")
  credits=$(echo "$credits_line" | awk '{print $2}')

  # Add to total credits
  total_credits=$((total_credits + credits))

  # Extract recent votes entries
  # We'll parse lines matching the pattern for recent votes
  recent_votes=$(echo "$output" | awk '/Recent Votes \(using 31\/31 entries\):/,0' | tail -n +2)

  # Collect latencies
  # Each line like: - slot: 73446926 (confirmation count: 1) (latency 1)
  while IFS= read -r line; do
    # Extract latency
    latency=$(echo "$line" | grep -o "(latency [0-9]\+)" | grep -o "[0-9]\+")
    if [ -n "$latency" ]; then
      latencies+=("$latency")
    fi
  done <<< "$recent_votes"
done

# Calculate average latency of last 31 entries
# Ensure we only consider the last 31 latencies if more collected
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

# Output: Credits and Average Latency on the same line
echo "Credits: $total_credits            Average Latency: $avg_latency"
