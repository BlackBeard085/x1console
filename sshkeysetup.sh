#!/bin/bash

# Function to generate SSH keys using Ed25519
generate_ssh_keys() {
    echo "You are about to generate new SSH keys, please ensure you are using your local machine for this."
    read -p "Do you wish to continue? (y/n): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Aborting SSH key generation."
        return
    fi

    # Prompt the user for their email address
    read -p "Enter your email address to associate with the SSH key: " user_email

    # Define the file where the SSH key will be stored
    KEY_FILE="$HOME/.ssh/id_ed25519"

    # Check if the key file already exists
    if [ -f "$KEY_FILE" ]; then
        echo "SSH key already exists at $KEY_FILE"
        echo "Do you want to overwrite it? (y/n)"
        read -r answer

        if [[ ! $answer =~ ^[Yy]$ ]]; then
            echo "Exiting without generating a new SSH key."
            return
        fi
    fi

    # Generate SSH key using the provided email
    ssh-keygen -t ed25519 -f "$KEY_FILE" -C "$user_email"

    # Set permissions for the new key
    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"

    echo "SSH key pair generated successfully:"
    echo "Private key: $KEY_FILE"
    echo "Public key: ${KEY_FILE}.pub"

    # After generating SSH keys, prompt the user to export the public key
    export_pubkey
}

# Function to export the public key to the remote server
export_pubkey() {
    echo "Exporting pubkey to the remote server."

    # Get the username, IP address, and custom port from the user
    read -p "Enter your server username: " server_username
    read -p "Enter the IP address or hostname of the server: " remote_host
    read -p "Enter the SSH port of the server (default is 22, press enter to use default): " ssh_port

    # If no port is specified, default to 22
    ssh_port=${ssh_port:-22}

    # Use ssh-copy-id to export the public key
    ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" -p "$ssh_port" "$server_username@$remote_host"

    if [ $? -eq 0 ]; then
        echo "Public key successfully exported to $remote_host on port $ssh_port."
    else
        echo "Failed to export the public key. Please check your username, IP address, and SSH port."
    fi
}

# Function to export SSH public keys
export_keys() {
    KEY_FILE="$HOME/.ssh/id_ed25519"

    # Check if the SSH keys exist
    if [ -f "${KEY_FILE}.pub" ]; then
        export_pubkey
    else
        echo "No SSH key found. Please generate the keys first."
    fi
}

# Function to configure SSH settings on the server
configure_ssh() {
    echo "Please only use this feature once SSH keys are generated and the public key is exported to the server."
    echo "This option is to be used only on the server. Do you wish to continue? (y/n)"
    read -r answer

    if [[ ! $answer =~ ^[Yy]$ ]]; then
        echo "Configuration aborted."
        return
    fi

    read -p "Enter the new SSH port (e.g., 2222): " new_port

    # Update SSH port, disable root login and disable password authentication
    echo "Updating SSH configuration..."

    # Change the port in the sshd_config file
    if grep -q "^Port" /etc/ssh/sshd_config; then
        sudo sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
    else
        echo "Port $new_port" | sudo tee -a /etc/ssh/sshd_config
    fi

    # Disable root login
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
    fi

    # Disable password authentication
    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
    fi

    # Allow the new port through UFW
    sudo ufw allow "$new_port"/tcp
    echo "UFW configured to allow SSH traffic on port $new_port."

    # Determine the correct command to restart SSH service
    if systemctl list-units --type=service | grep -i -q 'ssh'; then
        sudo systemctl daemon-reload
        if systemctl list-units --type=service | grep -i -q 'sshd'; then
            sudo systemctl restart sshd
        else
            sudo systemctl restart ssh
        fi
        # Restart the SSH socket if it exists
        if systemctl list-units --type=socket | grep -i -q 'ssh'; then
            sudo systemctl restart ssh.socket
        fi
    else
        echo "systemctl not available or SSH service not found."
    fi

    echo "SSH configuration updated successfully. Password authentication disabled, root login disabled."
}

# Main menu function
main_menu() {
    while true; do
        echo "Select an option:"
        echo "1. Generate SSH Keys"
        echo "2. Export SSH Public Key"
        echo "3. Configure Server for ssh Keys Login Only"
        echo "0. Exit"
        read -p "Please enter your choice: " choice

        case $choice in
            1)
                generate_ssh_keys
                ;;
            2)
                export_keys
                ;;
            3)
                configure_ssh
                ;;
            0)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Run the main menu
main_menu
