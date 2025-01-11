#!/bin/bash

# Function to print error messages
error_exit() {
  echo "$1" 1>&2
  exit 1
}

# Check if the script is run as root
if [[ $EUID -eq 0 ]]; then
  error_exit "This script should not be run as root. Please run it as your regular user."
fi

# START OF SCRIPT 1

# Update package index
echo "Updating package index..."
sudo apt update || error_exit "Failed to update package index."

# Install logrotate
echo "Installing logrotate..."
sudo apt install logrotate || error_exit "Failed to install logrotate."

# Install required packages
echo "Installing required packages..."
sudo apt install -y curl jq git || error_exit "Failed to install required packages."

# Download and install Solana CLI
echo "Downloading Solana CLI v1.18.25..."
sh -c "$(curl -sSfL https://release.solana.com/v1.18.25/install)" || error_exit "Failed to download Solana CLI."

# Export PATH variable
echo 'export PATH="$HOME/.local/share/solana/install/active/solana-release/bin:$PATH"' >> ~/.profile
echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc

# Load the new PATH in the current shell
export PATH="/home/ubuntu/.local/share/solana/install/active_release/bin:$PATH" && source ~/.profile && source ~/.bashrc

# Verify the installation
echo "Verifying Solana CLI installation..."
if solana --version; then
    echo "Solana CLI installed successfully!"
else
    error_exit "Solana CLI installation failed."
fi

# Update Solana CLI if there are updates available
echo "Checking for Solana CLI updates..."
solana-install update || error_exit "Failed to update Solana CLI."
echo "Solana CLI is up to date!"

# Tune the system for Solana validator
echo "Tuning the system for Solana validator..."

# Create the sysctl configuration for UDP buffer sizes and other settings
sudo bash -c "cat >/etc/sysctl.d/21-solana-validator.conf <<EOF
# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728
# Increase memory mapped files limit
vm.max_map_count = 1000000
# Increase number of allowed open file descriptors
fs.nr_open = 1000000
EOF"

# Apply the sysctl configuration
sudo sysctl -p /etc/sysctl.d/21-solana-validator.conf

# Increase systemd and session file limits
echo "Increasing systemd and session file limits..."
sudo bash -c "echo 'DefaultLimitNOFILE=1000000' >> /etc/systemd/system.conf"

# Reload the systemd daemon
sudo systemctl daemon-reload

# Create file limits configuration
sudo bash -c "cat >/etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 1000000
EOF"

echo "System tuning for Solana validator completed!"

# Install Rust and Cargo
echo "Installing Rust and Cargo..."
curl https://sh.rustup.rs -sSf | sh || error_exit "Failed to install Rust and Cargo."
source $HOME/.cargo/env || error_exit "Failed to source Cargo environment."
rustup component add rustfmt || error_exit "Failed to add rustfmt component."
rustup update || error_exit "Failed to update Rust."
sudo apt-get update || error_exit "Failed to update package index."
sudo apt-get install -y libssl-dev libudev-dev pkg-config zlib1g-dev llvm clang cmake make libprotobuf-dev protobuf-compiler || error_exit "Failed to install required development packages."

echo "Rust and Cargo installation completed successfully!"

# Build the solana-validator in the x1 directory
echo "Preparing to build solana-validator..."

# Get the current user's username
CURRENT_USER=$(whoami)

# Define the x1 directory path
X1_DIRECTORY="/home/$CURRENT_USER/x1"

# Check if the x1 directory exists, create it if it doesn't
if [ ! -d "$X1_DIRECTORY" ]; then
  echo "Creating directory $X1_DIRECTORY..."
  mkdir -p "$X1_DIRECTORY" || error_exit "Failed to create directory $X1_DIRECTORY."
fi

# Change to the x1 directory
cd "$X1_DIRECTORY" || error_exit "Failed to change to directory $X1_DIRECTORY."

# Clone the GitHub repository
echo "Cloning the solanalabs repository..."
git clone https://github.com/FairCrypto/solanalabs.git || error_exit "Failed to clone solanalabs repository."

# Change into the solanalabs directory
cd solanalabs || error_exit "Failed to change into solanalabs directory."

# Checkout the specified branch
echo "Checking out the dyn_fees_v1 branch..."
git checkout dyn_fees_v1 || error_exit "Failed to checkout dyn_fees_v1 branch."

# Confirm the current branch
echo "Confirming the current branch..."
git branch || error_exit "Failed to list branches."

# Build the solana-validator
echo "Building the solana-validator..."
cargo build --release || error_exit "Failed to build solana-validator."
echo "solana-validator built successfully!"

# Confirm the build output
echo "Confirming the build output..."
ls -l target/release/solana-validator || error_exit "Failed to confirm the solana-validator build output."

# Connect to the desired network
echo "Connecting to the desired network..."
solana config set -u https://rpc.testnet.x1.xyz || error_exit "Failed to set Solana configuration to the desired network."

# Confirm the configuration
echo "Confirming the Solana configuration..."
solana config get || error_exit "Failed to get Solana configuration."

echo "Setup completed successfully!"

# END OF SCRIPT 1

# START OF SCRIPT 2

# Specify the username if needed, otherwise use the current user's HOME
USERNAME=${1:-$USER}  # Take a username from the first argument or default to current user
HOME_DIR="/home/$USERNAME"
SOLANA_DIR="$HOME_DIR/.config/solana"
DEST_DIR="$HOME_DIR/x1/solanalabs"
WALLETS=("id.json" "identity.json" "vote.json" "stake.json")

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Initialize an empty array for wallet data
wallets=()

# Loop through each wallet file
for wallet in "${WALLETS[@]}"; do
    wallet_path="$SOLANA_DIR/$wallet"
    # Check if the wallet file exists
    if [[ ! -f "$wallet_path" ]]; then
        echo "Wallet $wallet not found. Creating..."
        solana-keygen new --no-passphrase -o "$wallet_path"
    else
        echo "Wallet $wallet already exists."
    fi
    # Copy the wallet file to the destination directory
    cp "$wallet_path" "$DEST_DIR"
    # Extract the wallet address using solana-keygen
    address=$(solana-keygen pubkey "$wallet_path")
    # Extract the name from the wallet file basename (without .json)
    name=$(basename "$wallet" .json)
    # Capitalize the first letter of the name
    name_capitalized="${name^}"
    # Add the wallet information to the wallets array
    wallets+=("{\"name\": \"$name_capitalized\", \"address\": \"$address\"}")
done

# Create the wallets.json file in the current directory
echo "[" > wallets.json
for i in "${!wallets[@]}"; do
    echo "  ${wallets[$i]}$([ $i -lt $((${#wallets[@]} - 1)) ] && echo ',')"  # Add a comma if it's not the last entry
done >> wallets.json
echo "]" >> wallets.json
echo "Wallets saved in wallets.json."
echo "Wallet files have been copied to $DEST_DIR."

# Function to fund a wallet via the faucet
fund_wallet() {
    local pubkey=$1
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"pubkey\":\"$pubkey\"}" https://xolana.xen.network/faucet)
    echo "Funding response for $pubkey: $response"
    echo "$response"
}

# Extract the address for the id wallet
id_address=$(solana-keygen pubkey "$SOLANA_DIR/id.json")

# Fund the id wallet
echo "Funding id wallet..."
fund_response=$(fund_wallet "$id_address")

# Print the raw funding response for clarity
echo -e "\nRaw funding response: $fund_response\n"

# Check for 'limit reached' in the funding response
if [[ "$fund_response" == *"limit reached"* ]]; then
    echo "Faucet limit reached, try again in 24 hours. Checking balance..."
    
    # Check the current balance
    balance_output=$(solana balance)
    echo -e "Current balance output:\n$balance_output\n"
    
    # Extract the balance value as a number
    current_balance=$(echo "$balance_output" | awk '{print $1}')
    
    # Check if the balance is 4 or more
    if (( $(echo "$current_balance >= 4" | bc -l) )); then
        echo "Balance is sufficient ($current_balance SOL). Proceeding with the rest of the script..."
        
        # Extract addresses for identity, stake, and vote wallets
        identity_address="$HOME/.config/solana/identity.json"
        stake_address="$HOME/.config/solana/stake.json"
        vote_address="$HOME/.config/solana/vote.json"
        
        # Get the withdrawer's wallet address from wallets.json
        withdrawer_address=$(jq -r '.[] | select(.name == "Withdrawer" or .name == "Id") | .address' wallets.json)

        echo "Transferring 1 SOL to identity wallet..."
        solana transfer "$identity_address" 1 --allow-unfunded-recipient

        echo "Creating stake account..."
        stake_creation_response=$(solana create-stake-account "$stake_address" 2)
        echo -e "Stake account creation response:\n$stake_creation_response\n"

        echo "Creating vote account..."
        vote_creation_response=$(solana create-vote-account "$vote_address" "$identity_address" "$withdrawer_address" --commission 10)
        echo -e "Vote account creation response:\n$vote_creation_response\n"

        # Message indicating that the script has reached completion
        echo "Stake and vote accounts created successfully."
    else
        echo "Insufficient balance ($current_balance SOL). Cannot proceed with the rest of the script."
    fi
else
    # Check if funding was successful
    if [[ "$fund_response" == *"success"* ]]; then
        echo "Funding successful! Proceeding with the next commands..."
        
        # Extract addresses for identity, stake, and vote wallets
        identity_address="$HOME/.config/solana/identity.json"
        stake_address="$HOME/.config/solana/stake.json"
        vote_address="$HOME/.config/solana/vote.json"
        
        # Get the withdrawer's wallet address from wallets.json
        withdrawer_address=$(jq -r '.[] | select(.name == "Withdrawer" or .name == "Id") | .address' wallets.json)

        echo "Transferring 1 SOL to identity wallet..."
        solana transfer "$identity_address" 1 --allow-unfunded-recipient

        echo "Creating stake account..."
        stake_creation_response=$(solana create-stake-account "$stake_address" 2)
        echo -e "Stake account creation response:\n$stake_creation_response\n"

        echo "Creating vote account..."
        vote_creation_response=$(solana create-vote-account "$vote_address" "$identity_address" "$withdrawer_address" --commission 10)
        echo -e "Vote account creation response:\n$vote_creation_response\n"

        # Message indicating that the script has reached completion
        echo "Stake and vote accounts created successfully." 
    else
        echo "Funding failed: $fund_response"
    fi
fi

# END OF SCRIPT 2
