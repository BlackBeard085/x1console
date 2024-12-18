const { exec } = require('child_process');
const os = require('os');

// Get the current user's username
const username = os.userInfo().username;

// Define the validator directory based on the current user
const validatorDirectory = `/home/${username}/x1/solanalabs/`;

// Command to stop the validator
const stopCommand = 'solana-validator exit -f';

// New command to start the validator
const startCommand = `target/release/solana-validator --identity ~/.config/solana/identity.json --vote-account ~/.config/solana/vote.json --known-validator C58LhVv822GiE3s84pwb58yiaezWLaFFdUtTWDGFySsU --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT --known-validator 5NfpgFCwrYzcgJkda9bRJvccycLUo3dvVQsVAK2W43Um --only-known-rpc --log $HOME/x1/log.txt --rpc-port 8899 --full-rpc-api --dynamic-port-range 8000-8020 --entrypoint xolana.xen.network:8001 --entrypoint owlnet.dev:8000 --wal-recovery-mode skip_any_corrupted_record --limit-ledger-size 50000000 --enable-rpc-transaction-history --enable-extended-tx-metadata-storage --rpc-pubsub-enable-block-subscription --full-snapshot-interval-slots 5000 --maximum-incremental-snapshots-to-retain 10 --maximum-full-snapshots-to-retain 50`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
        });
    });
}

// Function to run solana catchup
function runCatchup() {
    return new Promise((resolve, reject) => {
        exec('solana catchup --our-localhost', (error, stdout, stderr) => {
            if (error) {
                reject(`Error running catchup: ${stderr}`);
            } else {
                resolve(stdout); // Output from the catchup command
            }
        });
    });
}

// Execute the script
(async () => {
    try {
        const running = await isValidatorRunning();

        if (running) {
            console.log('Validator is running on port 8899. Stopping it now...');
            exec(`cd ${validatorDirectory} && ${stopCommand}`, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error stopping validator: ${stderr}`);
                } else {
                    console.log(stdout); // Output from the stop command
                }
            });
            console.log('Validator stopped.');
            // Wait a bit after stopping the validator
            console.log('Waiting 10 seconds before starting the validator...');
            await new Promise(res => setTimeout(res, 10000));
        } else {
            console.log('Validator is not currently running. Proceeding to start it.');
        }

        console.log('Starting the validator now...');
        exec(`cd ${validatorDirectory} && ${startCommand}`, { stdio: 'ignore' }, (error) => {
            if (error) {
                console.error(`Error starting validator: ${error.message}`);
            } else {
                console.log('Validator start command issued.');
            }
        });

        // Check if the validator has started successfully
        let attempts = 0;
        const maxAttempts = 10; // Maximum number of attempts to check the port
        const delayBetweenAttempts = 10; // Seconds to wait between checks

        while (attempts < maxAttempts) {
            await new Promise(res => setTimeout(res, delayBetweenAttempts * 1000));
            const isRunning = await isValidatorRunning();

            if (isRunning) {
                console.log('Validator started successfully and is running on port 8899.');

                // Countdown for 10 seconds before running the catchup command
                for (let i = 10; i > 0; i--) {
                    console.log(`Waiting for ${i} seconds for the validator to stabilize...`);
                    await new Promise(res => setTimeout(res, 1000));
                }

                // Run catchup command
                console.log('Running catchup command...');
                const catchupOutput = await runCatchup();
                console.log('Catchup command output:\n', catchupOutput);
                return; // Exit the script
            }

            attempts++;
            console.log(`Check ${attempts}: Validator not yet running...`);
        }

        console.log('Failed to start the validator. Port 8899 is still not in use. Please check logs for errors, remove ledger and start again');

    } catch (error) {
        console.error('Failed to manage validator:', error);
    } finally {
        // Ensure the script exits when done
        process.exit();
    }
})();
