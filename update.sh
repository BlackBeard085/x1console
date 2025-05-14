#!/bin/bash

#export solana PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

# Script to update Solana CLI and the application

TACHYON_DIR="$HOME/x1/tachyon"
BASE_DIR="$HOME/x1"  # Set the base directory

if [ -d "$TACHYON_DIR" ]; then
    cd "$TACHYON_DIR" || exit

    # Port to check
    PORT=3334
    # Get the PID of the process using the specified port
    PID=$(lsof -t -i :$PORT)
    if [ -z "$PID" ]; then
        echo "No process is using port $PORT."
    else
        echo "Killing Pinger on port $PORT with PID(s): $PID"
        kill -9 $PID
        echo "Process(es) terminated."
    fi

    echo -e "\nUpdating Server"
    sudo apt update && sudo apt upgrade

    echo -e "\nUpdating to most recent stable version of Solana CLI "
    sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)" || error_exit "Failed to download Solana CLI."

    echo -e "\nUpdating X1 Validator"
    git stash && git pull

    echo -e "\nCleaning up Cargo build..."
    cargo clean

    echo -e "\nBuilding project in release mode..."
    cargo build --release

    # Check if the validator is running on port 8899
    if lsof -i :8899; then
        echo -e "\nValidator is currently running. Stopping the validator..."
        # Change to the base directory to stop the validator
        cd "$BASE_DIR" || exit
        tachyon-validator exit -f
        sleep 7
        echo -e "Validator has been stopped."
        cd "$TACHYON_DIR" || exit  # Return to tachyon directory
    else
        echo -e "\nValidator is not running. Continuing with the update...\n"
    fi

    echo -e "\nCopying tachyon-validator to your path and bashrc..."
    cp "$HOME/x1/tachyon/target/release/tachyon-validator" "$HOME/.local/share/solana/install/active_release/bin/tachyon-validator"
    # cp -r ~/x1/tachyon/target/release/* ~/.local/share/solana/install/active_release/bin/
    export PATH=$PATH:~/x1/tachyon/target/release
    echo 'export PATH=$PATH:~/x1/tachyon/target/release' >> ~/.bashrc && source ~/.bashrc

    echo -e "\nCopying tachyon-validator to /usr/local/bin..."
    sudo cp "$HOME/x1/tachyon/target/release/tachyon-validator" /usr/local/bin
else
    echo -e "\nDirectory $TACHYON_DIR does not exist. Skipping Cargo commands.\n"
fi

echo -e "\nSystem updated.\n"

# Execute restart.js after updating
if [ -f "$HOME/x1console/restart.js" ]; then
    echo -e "\nRestarting pinger and validator after update..."
    node "$HOME/x1console/setpinger.js"
    node "$HOME/x1console/restart.js"
    if [ $? -eq 0 ]; then
        echo -e "\nRestart executed successfully.\n"
        cd ~/x1console
    else
        echo -e "\nFailed to restart.\n"
        cd ~/x1console
    fi
else
    echo -e "\nrestart.js does not exist in $HOME/x1console.\n"
fi

rm -rf ~/x1console/update_lock.pid
rm -rf ~/x1console/update_pause_time.txt
