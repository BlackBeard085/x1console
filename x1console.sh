#!/bin/bash

# Function to check if a Node.js package is installed
check_npm_package() {
    PACKAGE=$1

    # Check if the package is installed by looking for it in the node_modules directory
    if npm list -g --depth=0 | grep -q "$PACKAGE@"; then
        echo -e "\n$PACKAGE is already installed."
    else
        echo -e "\n$PACKAGE is not installed. Installing..."
        npm install -g "$PACKAGE"
    fi
}

# Function to check x1/solanalabs directory and handle user choice
check_solanalabs_directory() {
    SOLANALABS_DIR="$HOME/x1/solanalabs"
    ARCHIVE_DIR="$HOME/archive"

    if [ -d "$SOLANALABS_DIR" ]; then
        echo -e "\nx1/solanalabs directory already exists, do you wish to delete or archive this directory? (delete/archive)"
        read -r action
        
        case $action in
            delete)
                echo -e "\nDeleting $SOLANALABS_DIR..."
                rm -rf "$SOLANALABS_DIR"
                echo -e "$SOLANALABS_DIR has been deleted.\n"
                ;;
            archive)
                echo -e "\nArchiving $SOLANALABS_DIR..."
                # Check if archive directory exists; if not, create it
                mkdir -p "$ARCHIVE_DIR"
                # Move the solanalabs directory to archive
                mv -f "$SOLANALABS_DIR" "$ARCHIVE_DIR/"
                echo -e "$SOLANALABS_DIR has been moved to $ARCHIVE_DIR.\n"
                ;;
            *)
                echo -e "\nInvalid action. Continuing without deleting or archiving.\n"
                ;;
        esac
    fi
}

# Function to execute the install_run.sh script
install() {
    echo -e "\nDo you have existing X1 validator wallets? (yes/no)"
    read -r wallet_response
    if [[ "$wallet_response" == "yes" ]]; then
        echo -e "\nHave these been copied to the .config/solana directory? (yes/no)"
        read -r copied_response
        if [[ "$copied_response" == "yes" ]]; then
            echo -e "\nContinuing with X1 installation...\n"
        else
            echo -e "\nPlease copy these wallets to your '.config/solana' directory before starting X1 install."
            echo -e "Please note your id.json is also your withdrawer and sometimes saved as withdrawer.json; please rename it to id.json if needed.\n"
            exit 1
        fi
    else
        echo -e "\nYour validator wallets will be created for you. Continuing with X1 installation...\n"
    fi
    # Check x1/solanalabs directory before proceeding
    check_solanalabs_directory
    # Allowing the firewall for ports 8000 to 10000
    echo -e "\nConfiguring firewall to allow access to ports 8000-10000..."
    sudo ufw allow 8000:10000
    # Execute install_run.sh
    if [ -f ./install_run.sh ]; then
        echo -e "\nExecuting install_run.sh..."
        ./install_run.sh
        # Change the path for copying solana-validator to your
        echo -e "\nCopying solana-validator to your path..."
        cp "$HOME/x1/solanalabs/target/release/solana-validator" "$HOME/.local/share/solana/install/active_release/bin/solana-validator"
        sudo cp "$HOME/x1/solanalabs/target/release/solana-validator" /usr/local/bin
        echo -e "\nCopying wallets.json to x1console directory..."
        sudo cp "$HOME/x1/solanalabs/wallets.json" "$HOME/x1console"
        
        # New Addition: Attempt to execute activatestake.js
        echo -e "\nAttempting to execute activatestake.js..."
        if [ -f ./activatestake.js ]; then
            node ./activatestake.js
            if [ $? -eq 0 ]; then
                echo -e "\nactivatestake.js executed successfully.\n"
            else
                echo -e "\nFailed to execute activatestake.js.\n"
            fi
        else
            echo -e "\nactivatestake.js does not exist. Please create it in the directory.\n"
        fi

        # Attempting to restart validator
        echo -e "\nAttempting to restart validator..."
        if [ -f ./restart.js ]; then
            # Using spawn for executing restart.js
            node ./restart.js
            if [ $? -eq 0 ]; then
                echo -e "\nValidator has been restarted successfully."
                # Run setpinger.js after restart is successful
                if [ -f ./setpinger.js ]; then
                    echo -e "\nExecuting setpinger.js..."
                    node ./setpinger.js
                    if [ $? -eq 0 ]; then
                        echo -e "\nsetpinger.js executed successfully.\n"
                    else
                        echo -e "\nFailed to execute setpinger.js.\n"
                    fi
                else
                    echo -e "\nsetpinger.js does not exist. Please create it in the directory.\n"
                fi
            else
                echo -e "\nFailed to restart the validator.\n"
            fi
        else
            echo -e "\nrestart.js does not exist. Please create it.\n"
        fi
    else
        echo -e "\ninstall_run.sh does not exist. Please create it.\n"
    fi
}
pause

# Function to update Solana CLI and the application
update_x1() {
    SOLANALABS_DIR="$HOME/x1/solanalabs"

    if [ -d "$SOLANALABS_DIR" ]; then
        cd "$SOLANALABS_DIR" || exit

        # Check if the validator is running on port 8899
        if lsof -i :8899; then
            echo -e "\nValidator is currently running. Stopping the validator..."
            solana-validator exit -f
            echo -e "Validator has been stopped."
        else
            echo -e "\nValidator is not running. Continuing with the update...\n"
        fi

        echo -e "\nCleaning up Cargo build..."
        cargo clean

        echo -e "\nBuilding project in release mode..."
        cargo build --release

        echo -e "\nCopying solana-validator to /usr/local/bin..."
        sudo cp "$HOME/x1/solanalabs/target/release/solana-validator" /usr/local/bin
    else
        echo -e "\nDirectory $SOLANALABS_DIR does not exist. Skipping Cargo commands.\n"
    fi

    echo -e "\nSystem updated.\n"

    # Execute restart.js after updating
    if [ -f "$HOME/x1console/restart.js" ]; then
        echo -e "\nExecuting restart.js..."
        node "$HOME/x1console/restart.js"
        if [ $? -eq 0 ]; then
            echo -e "\nRestart script executed successfully.\n"
        else
            echo -e "\nFailed to execute the restart script.\n"
        fi
    else
        echo -e "\nrestart.js does not exist in $HOME/x1console.\n"
    fi
    
    pause
}

# Function to update the X1 console
update_x1_console() {
   # echo -e "\nStashing local changes..."
   # git stash

   # echo -e "\nPulling latest changes..."
    #git pull

    echo -e "\nX1 console update feature paused.\n"
    
    pause
}

# Function for health check and start validator
health_check() {
    echo -e "\nRunning setwithdrawer.js..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nRunning health.js..."
    HEALTH_OUTPUT=$(node "$HOME/x1console/health.js")
    echo -e "$HEALTH_OUTPUT"

    if echo "$HEALTH_OUTPUT" | grep -q "WARNING"; then
        echo -e "\nWARNING issued in health check."

        # Execute checkaccounts.js before getbalances.js
        echo -e "\nRunning checkaccounts.js..."
        node "$HOME/x1console/checkaccounts.js"

        echo -e "\nRunning getbalances.js..."
        node "$HOME/x1console/getbalances.js"

        echo -e "\nRunning checkstake.js..."
        STAKE_OUTPUT=$(node "$HOME/x1console/checkstake.js")
        echo -e "$STAKE_OUTPUT"

        if echo "$STAKE_OUTPUT" | grep -q "0 active stake"; then
            echo -e "\n0 active stake found. Running activatestake.js..."
            node "$HOME/x1console/activatestake.js"

            echo -e "\nRunning restart.js after activating stake..."
            node "$HOME/x1console/restart.js"
        else
            echo -e "\nActive stake found. Running restart.js..."
            node "$HOME/x1console/restart.js"
        fi
    else
        echo -e "\nNo WARNING issued in health check. Exiting.\n"
    fi
    
    pause
}

# New function to check balances
balances() {
    echo -e "\nRunning setwithdrawer.js..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nRunning checkaccounts.js..."
    if [ -f "$HOME/x1console/checkaccounts.js" ]; then
        node "$HOME/x1console/checkaccounts.js"
        if [ $? -eq 0 ]; then
            echo -e "\nAccounts checked successfully.\n"
        else
            echo -e "\nFailed to check accounts.\n"
        fi
    else
        echo -e "\ncheckaccounts.js does not exist. Please create it.\n"
    fi

    echo -e "\nRunning getbalances.js..."
    if [ -f "$HOME/x1console/getbalances.js" ]; then
        node "$HOME/x1console/getbalances.js"
        if [ $? -eq 0 ]; then
            echo -e "\nBalances checked successfully.\n"
        else
            echo -e "\nFailed to check balances.\n"
        fi
    else
        echo -e "\ngetbalances.js does not exist. Please create it.\n"
    fi
    
    pause
}

# Updated function to publish validator info
publish_validator() {
    echo -e "\nRunning setwithdrawer.js..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nPublishing validator information..."
    if [ -f "$HOME/x1console/publish.js" ]; then
        node "$HOME/x1console/publish.js"
        if [ $? -eq 0 ]; then
            echo -e "\nValidator info published on X1.\n"
        else
            echo -e "\nFailed to publish validator info.\n"
        fi
    else
        echo -e "\npublish.js does not exist. Please create it.\n"
    fi
    
    pause
}

# New function to manage pinger
pinger() {
    echo -e "\nChoose a subcommand:"
    echo -e "1. Restart Pinger"
    echo -e "2. Ping Times"
    read -p "Enter your choice [1-2]: " pinger_choice

    case $pinger_choice in
        1)
            restart_pinger
            ;;
        2)
            ping_times
            ;;
        *)
            echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
            ;;
    esac
}

# New function to restart pinger
restart_pinger() {
    echo -e "\nExecuting setpinger.js..."
    if [ -f "$HOME/x1console/setpinger.js" ]; then
        node "$HOME/x1console/setpinger.js"
        if [ $? -eq 0 ]; then
            echo -e "\nsetpinger.js executed successfully.\n"
        else
            echo -e "\nFailed to execute setpinger.js.\n"
        fi
    else
        echo -e "\nsetpinger.js does not exist. Please create it.\n"
    fi
    
    pause
}

# New function to check ping times
ping_times() {
    echo -e "\nFetching ping times...\n"
    curl http://localhost:3334/ping_times | jq
    echo -e "\nFinished fetching ping times. Returning to menu.\n"
    
    pause
}

# New function to display validator logs
show_logs() {
    echo -e "\nRunning validatorlogs.js..."
    if [ -f "$HOME/x1console/validatorlogs.js" ]; then
        node "$HOME/x1console/validatorlogs.js"
        if [ $? -eq 0 ]; then
            echo -e "\nvalidatorlogs.js executed successfully.\n"
        else
            echo -e "\nFailed to execute validatorlogs.js.\n"
        fi
    else
        echo -e "\nvalidatorlogs.js does not exist. Please create it.\n"
    fi
    
    pause
}

# New function to delete validator logs
delete_logs() {
    if lsof -i:8899; then
        echo -e "\nThe validator is currently running and must be turned off to delete validator logs."
        echo -e "Do you wish to continue? (yes/no)"
        read -r user_choice

        if [[ "$user_choice" == "yes" ]]; then
            echo -e "\nStopping the validator..."
            (cd "$HOME/x1/solanalabs/" && solana-validator exit -f)
            echo -e "Validator has been stopped."

            echo -e "\nDeleting log.txt..."
            rm -rf "$HOME/x1/log.txt"
            echo -e "\nValidator logs have been deleted. Please start your validator through the health check (option 3) which will start your validator.\n"
        else
            echo -e "\nOperation canceled. Returning to main menu.\n"
        fi
    else
        echo -e "\nValidator is not running. Deleting log.txt..."
        rm -rf "$HOME/x1/log.txt"
        echo -e "\nValidator logs have been deleted. Please start your validator through the health check (option 3) which will start your validator.\n"
    fi
    
    pause
}

# New Ledger function to manage Ledger commands
ledger() {
    echo -e "\nChoose a subcommand:"
    echo -e "1. Ledger Monitor"
    echo -e "2. Remove Ledger" 
    read -p "Enter your choice [1-2]: " ledger_choice

    case $ledger_choice in
        1)
            ledger_monitor
            ;;
        2)
            remove_ledger
            ;;
        *)
            echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
            ;;
    esac
}

# New function to monitor the ledger
ledger_monitor() {
    echo -e "\nStarting ledger monitoring. Press any key to stop...\n"
    
    # Navigate to the solanalabs directory and run the command
    cd "$HOME/x1/solanalabs/" || exit
    solana-validator --ledger ledger monitor & # Run in the background
    
    # Get the PID of the last command run in the background
    PID=$!
    
    # Wait for user input to stop the command
    read -n 1 -s -r -p "Press any key to stop the ledger monitoring..."
    
    # Kill the running process
    kill "$PID"
    echo -e "\nLedger monitoring stopped.\n"

    pause
}

# New function to remove the ledger
remove_ledger() {
    # Check if the validator is running using port 8899
    if lsof -i :8899; then
        echo -e "\nValidator is running. Ledger can only be removed when the validator has stopped."
        pause
        return
    fi

    # If validator is not running, ask for confirmation to remove ledger
    echo -e "\nAre you sure you wish to remove the ledger? (y/n)"
    read -r confirmation
    case $confirmation in
        y|Y)
            echo -e "\nRemoving the ledger..."
            rm -rf "$HOME/x1/solanalabs/ledger"
            echo -e "Ledger removed successfully.\n"
            ;;
        n|N)
            echo -e "\nOperation canceled. Returning to menu.\n"
            ;;
        *)
            echo -e "\nInvalid option. Returning to menu.\n"
            ;;
    esac
    
    pause
}

# New function for setting commission
set_commission() {
    # Run setwithdrawer.js
    echo -e "\nRunning setwithdrawer.js..."
    node "$HOME/x1console/setwithdrawer.js"

    # Prompt user for the commission percentage
    read -p "What percent would you like to set your commission at? (0-100): " commission_percent

    # Validate the user input
    if [[ "$commission_percent" -ge 0 ]] && [[ "$commission_percent" -le 100 ]]; then
        # Run the commission setting command
        echo -e "\nSetting commission to $commission_percent%..."
        solana vote-update-commission "$HOME/.config/solana/vote.json" "$commission_percent" "$HOME/.config/solana/id.json"
        if [ $? -eq 0 ]; then
            echo -e "\nCommission set successfully.\n"
        else
            echo -e "\nFailed to set commission.\n"
        fi
    else
        echo -e "\nInvalid percentage. Please enter a value between 0 and 100.\n"
    fi
    
    pause
}

# Function to exit the script
exit_script() {
    echo -e "\nExiting the script.\n"
    exit 0
}

# Function to pause and wait for user input
pause() {
    read -n 1 -s -r -p "Press any button to return to the menu..."
    echo -e "\n"
}

# Check if NVM is installed
if command -v nvm &> /dev/null; then
    echo -e "\nNVM is already installed."
else
    echo -e "\nNVM is not installed. Installing..."
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Load NVM into the current shell session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Source .bashrc to ensure the NVM command is available in the session
source ~/.bashrc

# Install Node.js version 20.0.0
nvm install v20.0.0

# Check for @solana/web3.js package
check_npm_package "@solana/web3.js"

# Make another script executable
if [ -f ./install_run.sh ]; then
    chmod +x ./install_run.sh
    echo -e "\ninstall_run.sh has been made executable.\n"
else
    echo -e "\ninstall_run.sh does not exist. Please create it.\n"
fi

# Print welcome message
echo -e "\nAHOY MI HEARTIES, WELCOME TO X1'S THE BLACK PEARL - THE INTERACTIVE, AUTOMATED X1 VALIDATOR MANAGER! YOUR DELEGATIONS ARE MUCH APPRECIATED!\n"

# Interaction to execute install function or update, health check, or exit
while true; do
    echo -e "\nChoose an option:"
    echo -e "1. Install, Start X1 and Pinger"
    echo -e "2. Update"
    echo -e "3. Health Check and Start Validator"
    echo -e "4. Check Balances"
    echo -e "5. Publish Validator"
    echo -e "6. Pinger"
    echo -e "7. Validator Logs"
    echo -e "8. Ledger"
    echo -e "9. Set Commission"
    echo -e "10. Exit"

    read -p "Enter your choice [1-10]: " choice

    case $choice in
        1)
            install

            # Display wallet addresses after installation
            echo -e "\n"

            # Read wallet addresses from wallets.json
            if [ -f "$HOME/x1/solanalabs/wallets.json" ]; then
                echo -e "Wallet Addresses:"
                # Using jq to parse the JSON file
                jq -r 'to_entries | .[] | "\(.key): \(.value)"' "$HOME/x1/solanalabs/wallets.json"
            else
                echo -e "\nwallets.json not found.\n"
            fi

            echo -e "\nThese are your pubkeys for your validator wallets; the private keys are stored in the .config/solana directory; please keep them safe.\n"
            echo -e "If this was your first installation, please copy the following command and run it in your terminal to be able to run the CLI straight away:"
            echo -e "\nexport PATH=\"/home/test2/.local/share/solana/install/active_release/bin:\$PATH\"\n"
            echo -e "\nIF THIS IS THE FIRST ISTALLATION LOG OUT AND BACK IN TO YOUR SERVER FOR CHANGES TO TAKE EFFECTn"
           
            # Indicate that setup is complete
            echo -e "Setup is complete.\n"
            continue
            ;;
        
        2)
            echo -e "\nChoose a subcommand:"
            echo -e "1. Update server"
            echo -e "2. Update X1 Console"
            read -p "Enter your choice [1-2]: " update_choice

            case $update_choice in
                1)
                    update_x1
                    continue
                    ;;
                2)
                    update_x1_console
                    continue
                    ;;
                *)
                    echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
                    continue
                    ;;
            esac
            ;;
        
        3)
            health_check
            continue
            ;;
        
        4)
            balances
            continue
            ;;
        
        5)
            publish_validator
            continue
            ;;
        
        6)
            pinger
            continue
            ;;
        
        7)
            echo -e "\nChoose a subcommand:"
            echo -e "1. Show Logs"
            echo -e "2. Delete Logs"
            read -p "Enter your choice [1-2]: " logs_choice
            case $logs_choice in
                1)
                    show_logs
                    continue
                    ;;
                2)
                    delete_logs
                    continue
                    ;;
                *)
                    echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
                    continue
                    ;;
            esac
            show_logs
            continue
            ;;
        
        8)
            ledger
            continue
            ;;
        
        9)
            set_commission
            continue
            ;;
        
        10)
            exit_script
            ;;
        
        *)
            echo -e "\nInvalid choice. Please choose from 1 to 10.\n"
            ;;
    esac
done
