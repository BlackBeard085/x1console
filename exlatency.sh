#!/bin/bash

# Path to your wallets.json
WALLETS_JSON="wallets.json"

# Initialize accumulators
total_credits=0
latencies=()

# Arrays for credits/max credits lines
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
  recent_votes=$(echo "$output" | awk '/Recent Votes \(using 31\/31 entries\):/,0' | tail -n +2)

  # Collect latencies
  while IFS= read -r line; do
    latency=$(echo "$line" | grep -o "(latency [0-9]\+)" | grep -o "[0-9]\+")
    if [ -n "$latency" ]; then
      latencies+=("$latency")
    fi
  done <<< "$recent_votes"

  # Collect all lines with 'credits/max credits: '
  while IFS= read -r line; do
    if echo "$line" | grep -q "credits/max credits:"; then
      credits_max_line=$(echo "$line" | grep "credits/max credits:")
      # Extract credits and max credits
      c=$(echo "$credits_max_line" | grep -oP "credits/max credits:\s*\K[0-9]+")
      m=$(echo "$credits_max_line" | grep -oP "credits/max credits:\s*[0-9]+/\K[0-9]+")
      credits_list+=("$c")
      max_credits_list+=("$m")
    fi
  done <<< "$output"
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

# Calculate average of credits and max credits from all lines
credits_sum=0
max_credits_sum=0
credits_count=${#credits_list[@]}
max_credits_count=${#max_credits_list[@]}

if [ "$credits_count" -gt 0 ]; then
  for c in "${credits_list[@]}"; do
    credits_sum=$((credits_sum + c))
  done
  # Get integer average (truncate decimal)
  avg_credits=$(echo "$credits_sum / $credits_count" | bc)
else
  avg_credits="N/A"
fi

if [ "$max_credits_count" -gt 0 ]; then
  for m in "${max_credits_list[@]}"; do
    max_credits_sum=$((max_credits_sum + m))
  done
  # Get integer average (truncate decimal)
  avg_max_credits=$(echo "$max_credits_sum / $max_credits_count" | bc)
else
  avg_max_credits="N/A"
fi

# Output: total credits, and average credits/max credits (without decimals)
echo "Credits:$total_credits    Avg Credits/Epoch:${avg_credits}/${avg_max_credits}    Avg Latency:$avg_latency"
