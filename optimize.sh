#!/bin/bash

# --- Configuration ---
MOUNT_POINT="/run/accounts"
TMPFS_SIZE="14G"
FSTAB_ENTRY="tmpfs   $MOUNT_POINT   tmpfs   defaults,size=$TMPFS_SIZE,mode=777   0   0"
FSTAB_FILE="/etc/fstab"

# --- Check current swappiness ---
echo "Checking current vm.swappiness..."
CURRENT_SWAPPINESS=$(sysctl -n vm.swappiness)
echo "Current vm.swappiness value: $CURRENT_SWAPPINESS"

# --- Set swappiness to 1 ---
echo "Setting vm.swappiness to 1 for optimal performance..."
sudo sysctl -w vm.swappiness=1

# --- Make the change persistent ---
if grep -q "^vm.swappiness" /etc/sysctl.conf; then
    echo "Updating existing vm.swappiness setting in /etc/sysctl.conf..."
    sudo sed -i "s/^vm.swappiness=.*/vm.swappiness=1/" /etc/sysctl.conf
else
    echo "Adding vm.swappiness=1 to /etc/sysctl.conf..."
    echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
fi

# --- Function to check if a directory is a mount point ---
is_mount_point() {
    mountpoint -q "$1"
}

# --- Check for root privileges ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

echo "--- Starting setup for tmpfs RAM disk ---"
echo "Mount Point: $MOUNT_POINT"
echo "Size: $TMPFS_SIZE"

# --- Step 1: Create the mount point directory if it doesn't exist ---
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point directory: $MOUNT_POINT"
    if mkdir -p "$MOUNT_POINT"; then
        echo "Directory created successfully."
        # Set permissions to 777 (sticky bit with full permissions)
        chmod 777 "$MOUNT_POINT"
    else
        echo "Error: Failed to create directory $MOUNT_POINT. Exiting."
        exit 1
    fi
else
    echo "Mount point directory '$MOUNT_POINT' already exists."
    # Ensure permissions are set correctly on existing directory
    chmod 777 "$MOUNT_POINT"
fi

# --- Step 2: Unmount if already mounted ---
if is_mount_point "$MOUNT_POINT"; then
    echo "Unmounting existing mount at $MOUNT_POINT..."
    if umount "$MOUNT_POINT"; then
        echo "Unmounted successfully."
    else
        echo "Warning: Failed to unmount $MOUNT_POINT. You may need to unmount manually."
    fi
else
    echo "$MOUNT_POINT is not currently mounted."
fi

# --- Step 3: Clean up existing entries in /etc/fstab ---
echo "Cleaning up existing entries for $MOUNT_POINT in $FSTAB_FILE..."

# Remove all entries that match either the exact mount point or similar tmpfs entries
sudo sed -i "\|^[^#].*[[:space:]]$MOUNT_POINT[[:space:]]|d" "$FSTAB_FILE"
sudo sed -i "\|^[^#].*tmpfs.*[[:space:]]$MOUNT_POINT[[:space:]]|d" "$FSTAB_FILE"

echo "Existing entries for $MOUNT_POINT removed."

# --- Step 4: Add new entry if not already present (double-check) ---
if ! grep -Fxq "$FSTAB_ENTRY" "$FSTAB_FILE"; then
    echo "Adding new fstab entry..."
    echo "$FSTAB_ENTRY" | sudo tee -a "$FSTAB_FILE"
    echo "Entry added."
else
    echo "The exact fstab entry already exists. No need to add."
fi

# --- Step 5: Mount all filesystems ---
echo "Mounting all filesystems..."
if mount -a; then
    echo "Mount operation successful."
    # Ensure permissions are set correctly after mount
    chmod 777 "$MOUNT_POINT"
else
    echo "Warning: 'mount -a' failed. Please check your /etc/fstab for errors."
fi

# --- Step 6: Verify the mount and permissions ---
echo "Verifying the mount and permissions..."
if df -h "$MOUNT_POINT" > /dev/null 2>&1; then
    echo "Verification successful: $MOUNT_POINT is mounted."
    df -h "$MOUNT_POINT"
    echo -e "\nCurrent permissions:"
    ls -ld "$MOUNT_POINT"
else
    echo "Verification failed: $MOUNT_POINT is not mounted."
fi

echo "--- Optimization completed ---"
