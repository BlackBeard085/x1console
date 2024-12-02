#!/bin/bash

# Function to check if speedtest-cli is installed
check_speedtest() {
    if command -v speedtest-cli &> /dev/null; then
        echo "speedtest-cli is already installed."
        run_speedtest
    else
        echo "speedtest-cli is not installed. Installing now..."
        install_speedtest
    fi
}

# Function to install speedtest-cli
install_speedtest() {
    # Check if the user is running a Debian-based system (Ubuntu, etc.)
    if [[ -x "$(command -v apt)" ]]; then
        sudo apt update
        sudo apt install -y speedtest-cli
    # Check if the user is running a Red Hat-based system (CentOS, Fedora, etc.)
    elif [[ -x "$(command -v yum)" ]]; then
        sudo yum install -y speedtest-cli
    # Check if the user is using macOS
    elif [[ -x "$(command -v brew)" ]]; then
        brew install speedtest-cli
    else
        echo "Unsupported package manager or OS. Please install speedtest-cli manually."
        return
    fi

    # Verify installation success and run speedtest
    if command -v speedtest-cli &> /dev/null; then
        echo "speedtest-cli has been installed successfully."
        run_speedtest
    else
        echo "Installation failed. Please check for any errors."
    fi
}

# Function to run the speedtest-cli command
run_speedtest() {
    echo "Running speedtest..."
    speedtest-cli
}

# Execute the check
check_speedtest
