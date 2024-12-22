const { exec } = require('child_process');
const os = require('os');

// Get the current user's username
const username = os.userInfo().username;
// Define the validator directory
const validatorDirectory = `/home/${username}/x1/solanalabs`;

// Command to start the validator
const startCommand = `$HOME/.local/share/solana/install/active_release/bin/solana-validator --identity ~/.config/solana/identity.json --vote-account ~/.config/solana/vote.json --known-validator C58LhVv822GiE3s84pwb58yiaezWLaFFdUtTWDGFySsU --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT --known-validator 5NfpgFCwrYzcgJkda9bRJvccycLUo3dvVQsVAK2W43Um --only-known-rpc --log $HOME/x1/log.txt --rpc-port 8899 --full-rpc-api --dynamic-port-range 8000-8020 --entrypoint xolana.xen.network:8001 --entrypoint owlnet.dev:8000 --wal-recovery-mode skip_any_corrupted_record --limit-ledger-size 50000000 --enable-rpc-transaction-history --enable-extended-tx-metadata-storage --rpc-pubsub-enable-block-subscription --full-snapshot-interval-slots 5000 --maximum-incremental-snapshots-to-retain 10 --maximum-full-snapshots-to-retain 50 --wait-for-supermajority 40364979 --expected-bank-hash o8f6X33oj9mUX3ZZdPMaTYDAKpAzpvfsEvEmn3RDAFH --expected-shred-version 12168`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
        });
    });
}

// Function to delegate stake
function delegateStake() {
    return new Promise((resolve, reject) => {
        // Specify the absolute path to the Solana command-line tool
        exec(`cd ${validatorDirectory} && ~/.local/share/solana/install/active_release/bin/solana delegate-stake stake.json vote.json`, (error, stdout, stderr) => {
            if (error) {
                reject(`Error delegating stake: ${stderr.trim()}`);
            } else {
                resolve(stdout.trim()); // Output from the delegate stake command
            }
        });
    });
}

// Execute the script
(async () => {
    try {
        // Delay the first check by 3 seconds
        await new Promise(res => setTimeout(res, 3000));
        
        const running = await isValidatorRunning();
        if (running) {
            console.log('Validator is already running on port 8899.');

            // Proceed to delegate stake
            const delegateOutput = await delegateStake();
            console.log('Delegate stake command output:\n', delegateOutput);
            console.log('Delegation successful, a restart is required.'); // Message to show after delegation
            return; // Exit the script after handling delegation
        } else {
            console.log('Validator is not currently running. Proceeding to start it.');
            console.log('Starting the validator now...');
            exec(`cd ${validatorDirectory} && ${startCommand} > /dev/null 2>&1`, (error) => {
                if (error) {
                    console.error(`Error starting validator. Check for fatal error.`);
                    return; // Exit if there was an error starting the validator
                }
            });

            // Check if the validator has started successfully
            for (let attempt = 0; attempt < 10; attempt++) {
                await new Promise(res => setTimeout(res, 10000)); // Wait for 10 seconds before checking
                const isRunning = await isValidatorRunning();
                if (isRunning) {
                    console.log('Validator started successfully and is running on port 8899.');
                    // Countdown for 10 seconds before proceeding to delegate stake
                    for (let i = 10; i > 0; i--) {
                        console.log(`Waiting for ${i} seconds for the validator to stabilize...`);
                        await new Promise(res => setTimeout(res, 1000));
                    }
                    // Proceed to delegate stake
                    const delegateOutput = await delegateStake();
                    console.log('Delegate stake command output:\n', delegateOutput);
                    console.log('Delegation successful, a restart is required.'); // Message to show after successful delegation
                    return; // Exit the script after handling delegation
                }
            }
            console.log('Failed to start the validator. Port 8899 is still not in use. Check logs for fatal error');
        }
    } catch (error) {
        console.error('Failed to manage validator:', error);
    } finally {
        // Ensure the script exits when done
        process.exit();
    }
})();
