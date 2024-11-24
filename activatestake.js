const fs = require('fs');
const { exec } = require('child_process');

const CONFIG_FILE = 'wallets.json';
const VALIDATOR_START_CMD = '$HOME/x1/agave-xolana/agave-validator --identity identity.json --limit-ledger-size 50000000 --log "$HOME/x1/log.txt" --vote-account vote.json --rpc-port 8899 --full-rpc-api --max-genesis-archive-unpacked-size 1073741824 --enable-rpc-transaction-history --enable-extended-tx-metadata-storage --rpc-pubsub-enable-block-subscription --entrypoint xolana.xen.network:8001 --only-known-rpc --known-validator C58LhVv822GiE3s84pwb58yiaezWLaFFdUtTWDGFySsU --expected-shred-version 19582 &';

// Function to load wallet addresses from the JSON file
function loadWallets() {
    if (fs.existsSync(CONFIG_FILE)) {
        try {
            const data = fs.readFileSync(CONFIG_FILE);
            return JSON.parse(data);
        } catch (error) {
            console.error('Failed to parse wallets.json:', error);
            return null;
        }
    }
    console.error('Configuration file not found:', CONFIG_FILE);
    return null;
}

// Function to delegate stake
function delegateStake(stakeWallet, voteWallet) {
    return new Promise((resolve, reject) => {
        const command = `solana delegate-stake ${stakeWallet} ${voteWallet}`;
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing command: ${stderr}`);
                return;
            }
            resolve(stdout);
        });
    });
}

// Function to check if the validator is running
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec('lsof -i :8899', (error, stdout) => {
            if (stdout) {
                resolve(true);  // If there's output, the port is in use
            } else {
                resolve(false);  // Port is not in use
            }
        });
    });
}

// Function to start the validator
function startValidator() {
    return new Promise((resolve, reject) => {
        exec(VALIDATOR_START_CMD, (error, stdout, stderr) => {
            if (error) {
                reject(`Error starting validator: ${stderr}`);
                return;
            }
            resolve(stdout);
        });
    });
}

// Main function to run the command
async function main() {
    const wallets = loadWallets();
    if (wallets) {
        const stakeWallet = wallets.find(wallet => wallet.name === 'Stake');
        const voteWallet = wallets.find(wallet => wallet.name === 'Vote');
        
        if (stakeWallet && voteWallet) {
            let validatorRunning = await isValidatorRunning();
            
            if (!validatorRunning) {
                console.log('Validator is not running. Starting the validator...');
                await startValidator();

                // Check if the validator is running, wait and retry
                const maxRetries = 10;
                const waitTime = 5000; // 5 seconds
                let retries = 0;

                while (retries < maxRetries) {
                    await new Promise(res => setTimeout(res, waitTime));
                    validatorRunning = await isValidatorRunning();
                    if (validatorRunning) {
                        console.log('Validator started successfully.');
                        break;
                    }
                    retries++;
                    console.log(`Checking if validator is running... Attempt ${retries}/${maxRetries}`);
                }

                if (!validatorRunning) {
                    console.error('Failed to start the validator after multiple attempts.');
                    process.exit(1);
                }
            } else {
                console.log('Validator is already running.');
            }
            
            // Now we can delegate stake
            try {
                const output = await delegateStake(stakeWallet.address, voteWallet.address);
                console.log('Stake activated, please restart your node:', output);
            } catch (error) {
                console.error('An error occurred while delegating stake:', error);
                process.exit(1);
            }
        } else {
            console.error('Stake or Vote wallet not found in wallets.json. Please check the file.');
            process.exit(1);
        }
    } else {
        console.error('No wallets found. Please ensure wallets.json exists.');
        process.exit(1);
    }
}

// Start the program
main();
