#!/bin/bash

# Define the cron entry
CRON_ENTRY="@reboot ~/x1console/start_on_reboot.sh"

# Get current crontab
TEMP_CRON=$(mktemp)
crontab -l > "$TEMP_CRON" 2>/dev/null || true

# Remove any existing entries matching our command
grep -v -F "~/x1console/start_on_reboot.sh" "$TEMP_CRON" > "$TEMP_CRON.new"

# Add our new entry
echo "$CRON_ENTRY" >> "$TEMP_CRON.new"

# Install the new crontab
crontab "$TEMP_CRON.new"

# Clean up
rm -f "$TEMP_CRON" "$TEMP_CRON.new"

echo "Cron job added successfully:"
echo "$CRON_ENTRY"
