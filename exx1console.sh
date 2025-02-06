#!/bin/bash

# Function to check if a Node.js package is installed
check_npm_package() {
    PACKAGE=$1

    # Check if the package is installed by looking for it in the node_modules directory
    if npm list -g --depth=0 | grep -q "$PACKAGE@"; then
        echo -e "\n$PACKAGE is already installed." > /dev/null 2>&1
    else
        echo -e "\n$PACKAGE is not installed. Installing..." > /dev/null 2>&1
        npm install -g "$PACKAGE" > /dev/null 2>&1
    fi
}

# Function to check x1/tachyon directory and handle user choice
check_tachyon_directory() {
    TACHYON_DIR="$HOME/x1/tachyon"
    ARCHIVE_DIR="$HOME/archive"

    if [ -d "$TACHYON_DIR" ]; then
        echo -e "\nx1/tachyon directory already exists, do you wish to delete or archive this directory? (delete/archive)"
        read -r action
        
        case $action in
            delete)
                echo -e "\nDeleting $TACHYON_DIR..."
                rm -rf "$TACHYON_DIR" && rm -rf $HOME/x1console/wallets.json && rm -rf $HOME/x1console/addressbook.json
                echo -e "$TACHYON_DIR has been deleted.\n"
                ;;
            archive)
                echo -e "\nArchiving $TACHYON_DIR..."
                # Check if archive directory exists; if not, create it
                mkdir -p "$ARCHIVE_DIR"
                # Move the tachyon directory to archive
                mv -f "$TACHYON_DIR" "$ARCHIVE_DIR/"
                echo -e "$TACHYON_DIR has been moved to $ARCHIVE_DIR.\n"
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
    # Check x1/tachyon directory before proceeding
    check_tachyon_directory
    # Allowing the firewall for ports 8000 to 10000
    echo -e "\nConfiguring firewall to allow access to ports 8000-10000 and 3334..."
    sudo ufw allow 8000:10000/tcp
    sudo ufw allow 8000:10000/udp
    sudo ufw allow 3334
    
    #killing all processes on port 8899
    pkill -f solana-validator
    # Execute install_run.sh
    if [ -f ./install_run.sh ]; then
        echo -e "\nExecuting install ..."
        ./install_run.sh
        # Change the path for copying tachyon-validator to your
        echo -e "\nCopying tachyon-validator to your path..."
        cp "$HOME/x1/tachyon/target/release/tachyon-validator" "$HOME/.local/share/solana/install/active_release/bin/tachyon-validator"
        sudo cp "$HOME/x1/tachyon/target/release/tachyon-validator" /usr/local/bin
       export PATH=$PATH:~/x1/tachyon/target/release
       echo 'export PATH=$PATH:~/x1/tachyon/target/release' >> ~/.bashrc && source ~/.bashrc 
       echo -e "\nCopying wallets.json to x1console directory..."
        cp "$HOME/x1/tachyon/wallets.json" "$HOME/x1console"

        echo -e "\nIncreasing systemd and session file limits"
        ulimit -n 1000000

        #setup logrotation
        echo -e "\nsetting up logrotation, executing setup_logrotation.sh..."
        ./setup_logrotate.sh
        
        #killing all processes on port 8899
	pkill -f solana-validator
	pkill -f tachyon-validator

	# remove old ledger
	echo -e "\nRemoving old ledger"
	rm -rf "$HOME/x1/ledger"

        # New Addition: Attempt to execute 1ststake.js
        echo -e "\nAttempting to execute 1ststake.js..."
        if [ -f ./1ststake.js ]; then
            node ./1ststake.js
            if [ $? -eq 0 ]; then
                echo -e "\n1ststake.js executed successfully.\n"
            else
                echo -e "\nFailed to execute 1ststake.js.\n"
            fi
        else
            echo -e "\n1ststake.js does not exist. Please create it in the directory.\n"
        fi

        # Attempting to restart validator
        echo -e "\nAttempting to restart validator..."
        if [ -f ./1strestart.js ]; then
            # Using spawn for executing 1strestart.js
            node ./1strestart.js
            if [ $? -eq 0 ]; then
                echo -e "\nValidator has been restarted successfully."
                # Run setpinger.js after restart is successful
                if [ -f ./setpinger.js ]; then
                    echo -e "\nSetting up pinger..."
                    node ./setpinger.js
                    if [ $? -eq 0 ]; then
                        echo -e "\nPinger set up successfully.\n"
                    else
                        echo -e "\nFailed to set up pinger.\n"
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

# Function to update Solana CLI and the application
update_x1() {
    TACHYON_DIR="$HOME/x1/tachyon"
    BASE_DIR="$HOME/x1"  # Set the base directory

    if [ -d "$TACHYON_DIR" ]; then
        cd "$TACHYON_DIR" || exit

        # Check if the validator is running on port 8899
        if lsof -i :8899; then
            echo -e "\nValidator is currently running. Stopping the validator..."
            # Change to the base directory to stop the validator
            cd "$BASE_DIR" || exit
            tachyon-validator exit -f
            echo -e "Validator has been stopped."
            cd "$TACHYON_DIR" || exit  # Return to tachyon directory
        else
            echo -e "\nValidator is not running. Continuing with the update...\n"
        fi

        echo -e "\nUpdating Server"
        sudo apt update && sudo apt upgrade

        echo -e "\nUpdating X1 Validator"
        git stash && git pull

        echo -e "\nCleaning up Cargo build..."
        cargo clean

        echo -e "\nBuilding project in release mode..."
        cargo build --release
       
        echo -e "\nCopying tachyon-validator to your path..."
        cp "$HOME/x1/tachyon/target/release/tachyon-validator" "$HOME/.local/share/solana/install/active_release/bin/tachyon-validator"

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
        echo -e "\nRestarting validator after update..."
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
    
    pause
}

# Function to update the X1 console
update_x1_console() {
    echo -e "\nStashing local changes..."
    git stash

    echo -e "\nPulling latest changes..."
    git pull

    echo -e "\nX1 console updated.\n"
    
    pause
}

# Function for health check and start validator
health_check() {
    echo -e "\nSetting withdrawer..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nRunning health.js..."
    HEALTH_OUTPUT=$(node "$HOME/x1console/health.js")
    echo -e "$HEALTH_OUTPUT"

    if echo "$HEALTH_OUTPUT" | grep -q "WARNING"; then
        echo -e "\nWARNING issued in health check."

        # Execute checkaccounts.js before getbalances.js
        echo -e "\nChecking accounts..."
        node "$HOME/x1console/checkaccounts.js"

        echo -e "\nChecking balances..."
        node "$HOME/x1console/getbalances.js"

        echo -e "\nChecking stake..."
        STAKE_OUTPUT=$(node "$HOME/x1console/checkstake.js")
        echo -e "$STAKE_OUTPUT"

        if echo "$STAKE_OUTPUT" | grep -q "0 active stake"; then
            echo -e "\n0 active stake found. Running activate stake..."
            node "$HOME/x1console/activatestake.js"

            echo -e "\nAttempting restart after activating stake..."
            node "$HOME/x1console/restart.js"
        else
            echo -e "\nActive stake found. Attempting restart..."
            node "$HOME/x1console/restart.js"
        fi
    else
        echo -e "\nNo WARNING issued in health check. Exiting.\n"
    fi
    
    pause
}

# New function to check balances
balances() {
    echo -e "\nSetting withdrawer..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nChecking accounts..."
    if [ -f "$HOME/x1console/checkaccounts.js" ]; then
        node "$HOME/x1console/checkaccounts.js"
        if [ $? -eq 0 ]; then
            echo -e "\nAccounts checked successfully.\n"
        else
            echo -e "\nUnable to send funds to underfunded wallets.\n"
        fi
    else
        echo -e "\ncheckaccounts.js does not exist. Please create it.\n"
    fi

    echo -e "\nChecking balances..."
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
    echo -e "\nSetting withdrawer..."
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
    echo -e "\nRestarting pinger set up..."
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

# New function for managing the ledger
ledger() {
    echo -e "\nChoose a subcommand:"
    echo -e "1. Ledger Monitor"
    echo -e "2. Remove Ledger"
    echo -e "3. Backup Ledger"
    read -p "Enter your choice [1-3]: " ledger_choice
    case $ledger_choice in
        1)
            ledger_monitor
            ;;
        2)
            remove_ledger
            ;;
        3)
            backup_ledger
            ;;
        *)
            echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
            ;;
    esac
}

# New function to monitor the ledger
ledger_monitor() {
    echo -e "\nStarting ledger monitoring. Press any key to stop...\n"
    # Navigate to the tachyon directory and run the command
    cd "$HOME/x1/" || exit
    tachyon-validator --ledger ledger monitor & # Run in the background
    # Get the PID of the last command run in the background
    PID=$!
    # Wait for user input to stop the command
    read -n 1 -s -r -p "Press any key to stop the ledger monitoring..."
    # Kill the running process
    kill "$PID"
    echo -e "\nLedger monitoring stopped.\n"
    cd ~/x1console
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
            rm -rf "$HOME/x1/ledger"
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

# New function to backup the ledger
backup_ledger() {
    # Check if the validator is running using port 8899
    if lsof -i :8899; then
        echo -e "\nValidator is running. Ledger backup can only be performed when the validator has stopped."
        pause
        return
    fi
    
    # Check if the ledger directory exists
    if [ -d "$HOME/x1/ledger" ]; then
        echo -e "\nCreating a backup of the ledger..."
        cp -r "$HOME/x1/ledger" "$HOME/x1/ledger.bak"
        if [ $? -eq 0 ]; then
            echo -e "Backup created successfully at $HOME/x1/ledger.bak.\n"
        else
            echo -e "Failed to create backup.\n"
        fi
    else
        echo -e "\nLedger directory does not exist. Unable to backup.\n"
    fi
    pause
}

# New function for setting commission
set_commission() {
    # Run setwithdrawer.js
    echo -e "\nSetting withdrawer..."
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

# Function for 'Other' menu
other_options() {
    while true; do
        echo -e "\nChoose an option under 'Other':"
        echo -e "1. Install, Start X1 and Pinger or [RESET]"
        echo -e "2. Update"
        echo -e "3. Autopilot"
        echo -e "4. Pinger"
        echo -e "5. Speed Test"
        echo -e "6. Return to Main Menu"
        read -p "Enter your choice [1-6]: " other_choice

        case $other_choice in
            1)
                install
            # Display wallet addresses after installation
            echo -e "\n"
            # Read wallet addresses from wallets.json
            if [ -f "$HOME/x1/tachyon/wallets.json" ]; then
                echo -e "Wallet Addresses:"
                # Using jq to parse the JSON file
                jq -r 'to_entries | .[] | "\(.key): \(.value)"' "$HOME/x1/tachyon/wallets.json"
            else
                echo -e "\nwallets.json not found.\n"
            fi
            echo -e "\nThese are your pubkeys for your validator wallets; the private keys are stored in the .config/solana directory; please keep them safe.\n"
            echo -e "If this was your first installation, please copy the following command and run it in your terminal to be able to run the CLI straight away:"
            echo -e "\nexport PATH=\"$HOME/.local/share/solana/install/active_release/bin:\$PATH\"\n"
            echo -e "\nPLEASE LOG OUT AND BACK IN TO YOUR SERVER FOR CHANGES TO TAKE EFFECTn"
           
            # Indicate that setup is complete
            echo -e "Setup is complete.\n"
                ;;
            2)
                echo -e "\nChoose a subcommand:"
                echo -e "1. Update X1 Validator"
                echo -e "2. Update X1 Console"
                read -p "Enter your choice [1-2]: " update_choice

                case $update_choice in
                    1)
                        update_x1
                        ;;
                    2)
                        update_x1_console
                        ;;
                    *)
                        echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
                        ;;
                esac
                ;;
            3)
	        # Execute setautopilot.sh when chosen
                echo -e "\nExecuting Autopilot setup"
                if [ -f "$HOME/x1console/setautopilot.sh" ]; then
                    bash "$HOME/x1console/setautopilot.sh"
                    if [ $? -eq 0 ]; then
                        echo -e "\nAutopilot setup complete.\n"
                    else
                        echo -e "\nFailed to set autopilot.\n"
                    fi
                else
                    echo -e "\nsetautopilot.sh does not exist. Please create it in the x1console directory.\n"
                fi
                ;;
            4)  pinger
                ;;
            5)
                # Execute speedtest.sh when chosen
                echo -e "\nExecuting speed test..."
                if [ -f "$HOME/x1console/speedtest.sh" ]; then
                    bash "$HOME/x1console/speedtest.sh"
                    if [ $? -eq 0 ]; then
                        echo -e "\nSpeed test completed successfully.\n"
                    else
                        echo -e "\nFailed to execute speed test.\n"
                    fi
                else
                    echo -e "\nspeedtest.sh does not exist. Please create it in the x1console directory.\n"
                fi
                ;;
            6)
                break
                ;;
            *)
                echo -e "\nInvalid choice. Please choose from 1 to 5.\n"
                ;;
        esac
    done
}

# Function to handle transfers and an address book
transfers() {
    while true; do
        echo -e "\nChoose a subcommand for Transfers:"
        echo -e "1. Transfer"
        echo -e "2. Address Book"
        echo -e "3. Return to Main Menu"
        read -p "Enter your choice [1-3]: " transfer_choice

        case $transfer_choice in
            1)
                echo -e "\nRunning setwithdrawer.js..."
                node "$HOME/x1console/setwithdrawer.js"

                echo -e "\nRunning transfer.js..."
                if [ -f "$HOME/x1console/transfer.js" ]; then
                    node "$HOME/x1console/transfer.js"
                    if [ $? -eq 0 ]; then
                        echo -e "\nTransfer completed successfully.\n"
                    else
                        echo -e "\nTransfer failed.\n"
                    fi
                else
                    echo -e "\ntransfer.js does not exist. Please create it.\n"
                fi
                pause
                ;;
            2)
                echo -e "\nRunning addressbook.js..."
                if [ -f "$HOME/x1console/addressbook.js" ]; then
                    node "$HOME/x1console/addressbook.js"
                    if [ $? -eq 0 ]; then
                        echo -e "\nAddress Book accessed successfully.\n"
                    else
                        echo -e "\nFailed to access Address Book.\n"
                    fi
                else
                    echo -e "\naddressbook.js does not exist. Please create it.\n"
                fi
                pause
                ;;
            3)
                break
                ;;
            *)
                echo -e "\nInvalid choice. Please choose from 1 to 3.\n"
                ;;
        esac
    done
}

# Function for managing stake
manage_stake() {
    echo -e "\nRunning stake manager..."
    if [ -f "$HOME/x1console/managestake.sh" ]; then
        bash "$HOME/x1console/managestake.sh"
        if [ $? -eq 0 ]; then
            echo -e "\nManage Stake completed successfully.\n"
        else
            echo -e "\nFailed to manage stake.\n"
        fi
    else
        echo -e "\nmanagestake.sh does not exist. Please create it.\n"
    fi
    pause
}

# Function for withdrawing stake/vote
withdraw_stake_vote() {
    echo -e "\nRunning withdrawls..."
    if [ -f "$HOME/x1console/withdraw.sh" ]; then
        bash "$HOME/x1console/withdraw.sh"
        if [ $? -eq 0 ]; then
            echo -e "\nWithdraw Stake/Vote completed successfully.\n"
        else
            echo -e "\nFailed to withdraw stake/vote.\n"
        fi
    else
        echo -e "\nwithdraw.sh does not exist. Please create it.\n"
    fi
    pause
}

# Placeholder function for speed test (this will be handled in other_options now)
speed_test() {
    echo -e "\nRunning Speed Test...\n"
    # Placeholder for speed test logic
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
    echo -e "\nNVM is already installed." > /dev/null 2>&1
else
    echo -e "\nNVM is not installed. Installing..." > /dev/null 2>&1
    # Install NVM
    curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash > /dev/null 2>&1

    # Load NVM into the current shell session
    export NVM_DIR="$HOME/.nvm" > /dev/null 2>&1
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" > /dev/null 2>&1
fi

# Source .bashrc to ensure the NVM command is available in the session
source ~/.bashrc > /dev/null 2>&1

# Install Node.js version 20.0.0
nvm install v20.0.0 > /dev/null 2>&1

# Check for @solana/web3.js package
check_npm_package "@solana/web3.js" > /dev/null 2>&1

# Print welcome message
echo -e "\nAHOY MI HEARTIES, WELCOME TO X1'S THE BLACK PEARL - THE INTERACTIVE, AUTOMATED X1 VALIDATOR MANAGER! YOUR DELEGATIONS ARE MUCH APPRECIATED! ==============FOR FIRST TIME USER NAVIGATE TO OTHER MENU, OPTION 10, THEN OPTION 1. INSTALL, START X1 AND PINGER==========AFTER FIRST INSTALL CLOSE YOUR TERMINAL WINDOW AND RELOGIN TO YOUR SERVER FOR ALL SYSTEM CHANGES TO TAKE EFFECT AND VALIDATOR STATUS TO UPDATE\n"

# Interaction to execute install function or update, health check, or exit
while true; do
    node newstatus.js
    echo " "
    node epoch.js
    echo -e "\nChoose an option:"
    echo -e "1. Health Check and Start Validator"
    echo -e "2. Validator"
    echo -e "3. Check Balances"
    echo -e "4. Transfers"
    echo -e "5. Manage Stake"
    echo -e "6. Withdraw Stake/Vote"
    echo -e "7. Ledger"
    echo -e "8. Set Commission"
    echo -e "9. Publish Validator"
    echo -e "10. Other"
    echo -e "11. Exit"

    read -p "Enter your choice [1-11]: " choice

    case $choice in
        1)
            health_check
            continue
            ;;
        
        2)
            echo -e "\nRunning validator manager..."
            if [ -f "$HOME/x1console/manageval.sh" ]; then
                bash "$HOME/x1console/manageval.sh"
                if [ $? -eq 0 ]; then
                    echo -e "\nValidator management completed successfully.\n"
                else
                    echo -e "\nFailed to manage validator.\n"
                fi
            else
                echo -e "\nmanageval.sh does not exist. Please create it.\n"
            fi
            pause
            continue
            ;;
        
        3)
            balances
            continue
            ;;
        
        4)
            transfers
            continue
            ;;
        
        5)
            manage_stake
            continue
            ;;
        
        6)
            withdraw_stake_vote
            continue
            ;;
        
        7)
            ledger
            continue
            ;;
        
        8)
            set_commission
            continue
            ;;
        
        9)
            publish_validator
            continue
            ;;
        
        10)
            other_options
            continue
            ;;
        
        11)
            exit_script
            ;;
        
        *)
            echo -e "\nInvalid choice. Please choose from 1 to 11.\n"
            ;;
    esac
done
