#!/bin/bash

# Define your directory
DIR="$HOME/x1console"

# Ask if you have sent a message to the bot
echo -n "Have you sent a message to the Telegram bot you wish to connect to? (y/n): "
read RESPONSE

# Check user's response
if [[ "$RESPONSE" != [Yy] ]]; then
    echo "Please send a message to the bot first, then return to set up Telegram bot."
    exit 1
fi

# Prompt user for Telegram bot token
echo -n "Please enter your Telegram bot token: "
read TOKEN_INPUT

# Validate token input
if [ -z "$TOKEN_INPUT" ]; then
    echo "No token entered. Exiting setup. Please provide a valid token."
    exit 1
fi

# Save the token to telegram_token.txt
echo "$TOKEN_INPUT" > "$DIR/telegram_token.txt"
echo "Token saved to $DIR/telegram_token.txt."

# Ask user which chat ID to retrieve
echo "Which chat ID would you like to retrieve?"
echo "1) Personal chat ID"
echo "2) Group/Channel chat ID"
echo -n "Enter 1 or 2: "
read CHOICE

# Fetch updates
RESPONSE=$(curl -s "https://api.telegram.org/bot$TOKEN_INPUT/getUpdates")

if [ "$CHOICE" = "1" ]; then
    # Get personal chat IDs (exclude IDs starting with '-')
    CHAT_ID=$(echo "$RESPONSE" | grep -Po '"chat":\s*{\s*"id":\s*\K-?\d+' | grep -v '^-')
    ID_TYPE="Personal"
elif [ "$CHOICE" = "2" ]; then
    # Get group/channel chat IDs (IDs starting with '-')
    CHAT_ID=$(echo "$RESPONSE" | grep -Po '"chat":\s*{\s*"id":\s*\K-?\d+' | grep '^-' )
    ID_TYPE="Group/Channel"
else
    echo "Invalid choice. Please run the script again and select 1 or 2."
    exit 1
fi

# Remove duplicate IDs and get the first one
UNIQUE_ID=$(echo "$CHAT_ID" | sort -n | uniq | head -n 1)

# Save the ID if found
if [ -n "$UNIQUE_ID" ]; then
    echo "$UNIQUE_ID" > "$DIR/chat_id.txt"
    echo "$ID_TYPE chat ID saved to $DIR/chat_id.txt: $UNIQUE_ID"
else
    echo "No $ID_TYPE chat ID found. Make sure you've sent a message to the bot and try again."
fi
