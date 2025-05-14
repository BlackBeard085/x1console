#!/bin/bash

# Get current username
CURRENT_USER=$(whoami)

# Define the commands to allow passwordless sudo for
COMMANDS="/usr/bin/apt, /usr/bin/apt-get, /bin/kill, /usr/local/bin/tachyon-validator, /bin/cp"

# Define the rule filename
RULE_FILE="/etc/sudoers.d/${CURRENT_USER}_passwordless"

# Create the rule content
SUDOERS_RULE="$CURRENT_USER ALL=(ALL) NOPASSWD: $COMMANDS"

# Check if the rule file already exists and contains the rule
if sudo grep -Fxq "$SUDOERS_RULE" "$RULE_FILE" 2>/dev/null; then
    echo "Passwordless sudo rule already exists in $RULE_FILE."
    exit 0
fi

# Create a temporary file for visudo validation
TMP_FILE=$(mktemp)

# Write the rule to the temporary file
echo "$SUDOERS_RULE" > "$TMP_FILE"

# Validate the syntax of the new rule file
if sudo visudo -cf "$TMP_FILE"; then
    # Backup existing rule file if it exists
    if [ -f "$RULE_FILE" ]; then
        sudo cp "$RULE_FILE" "${RULE_FILE}.bak"
        echo "Existing rule backed up to ${RULE_FILE}.bak"
    fi
    # Move the validated file into /etc/sudoers.d/
    sudo cp "$TMP_FILE" "$RULE_FILE"
    sudo chmod 440 "$RULE_FILE"
    echo "Passwordless sudo rule added successfully in $RULE_FILE."
else
    echo "Error: Syntax validation failed. Not applying changes."
fi

# Cleanup
rm "$TMP_FILE"
