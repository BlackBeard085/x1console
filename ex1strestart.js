const { exec } = require('child_process');
const os = require('os');

// Get the current user's username
const username = os.userInfo().username;

// Define the validator directory based on the current user
const validatorDirectory = `/home/${username}/x1/solanalabs/`;

// Command to stop the validator
const stopCommand = 'solana-validator exit -f';

// New command to start the validator
const startCommand = `target/release/solana-validator --identity $HOME/.config/solana/identity.json --limit-ledger-size 50000000 --rpc-port 8899 --entrypoint xolana.xen.network:8001 --full-rpc-api --log $HOME/x1/log.txt --vote-account $HOME/.config/solana/vote.json --max-genesis-archive-unpacked-size 1073741824 --require-tower --enable-rpc-transaction-history --enable-extended-tx-metadata-storage --rpc-pubsub-enable-block-subscription --only-known-rpc --known-validator C58LhVv822GiE3s84pwb58yiaezWLaFFdUtTWDGFySsU --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT --expected-shred-version 19582 --minimal-snapshot-download-speed 5000000 --full-snapshot-interval-slots 300 --maximum-incremental-snapshots-to-retain 100 --maximum-full-snapshots-to-retain 50`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
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
        const delayBetweenAttempts = 5; // Seconds to wait between checks

        while (attempts < maxAttempts) {
            await new Promise(res => setTimeout(res, delayBetweenAttempts * 1000));
            const isRunning = await isValidatorRunning();

            if (isRunning) {
                console.log('Validator started successfully and is running on port 8899.');
                return; // Exit the script as the validator is now running
            }

            attempts++;
            console.log(`Check ${attempts}: Validator not yet running...`);
        }

        console.log('Failed to start the validator. Port 8899 is still not in use.');

    } catch (error) {
        console.error('Failed to manage validator:', error);
    } finally {
        // Ensure the script exits when done
        process.exit();
    }
})();
