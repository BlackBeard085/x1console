#!/bin/bash

# Define variables
USERNAME=$(whoami)
LOGFILE="$HOME/x1/log.txt"
CONFIGFILE="/etc/logrotate.d/validatorlog"

# Create the logrotate configuration file
cat << EOF | sudo tee $CONFIGFILE
$LOGFILE {
    size 25G
    copytruncate
    missingok
    notifempty
    compress
    delaycompress
    create 0640 $USERNAME $USERNAME
    rotate 1
}
EOF

# Set proper permissions for the config file
sudo chown root:root $CONFIGFILE
sudo chmod 644 $CONFIGFILE

echo "Logrotate configuration created for $LOGFILE at $CONFIGFILE."
