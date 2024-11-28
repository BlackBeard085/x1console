const { exec } = require('child_process');
const os = require('os');

// Get the current user's username
const username = os.userInfo().username;
// Define the validator directory based on the current user
const validatorDirectory = `/home/${username}/x1/solanalabs`;

// Command to start the validator
const startCommand = `target/release/solana-validator --identity $HOME/.config/solana/identity.json --limit-ledger-size 50000000 --rpc-port 8899 --entrypoint xolana.xen.network:8001 --full-rpc-api --log - --vote-account $HOME/.config/solana/vote.json --max-genesis-archive-unpacked-size 1073741824 --require-tower --enable-rpc-transaction-history --enable-extended-tx-metadata-storage --rpc-pubsub-enable-block-subscription --only-known-rpc --known-validator C58LhVv822GiE3s84pwb58yiaezWLaFFdUtTWDGFySsU --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT --expected-shred-version 19582 --minimal-snapshot-download-speed 5000000 --full-snapshot-interval-slots 300 --maximum-incremental-snapshots-to-retain 100 --maximum-full-snapshots-to-retain 50`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
        });
    });
}

// Function to run Solana catchup
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

// Function to delegate stake
function delegateStake() {
    return new Promise((resolve, reject) => {
        exec(`cd ${validatorDirectory} && solana delegate-stake stake.json vote.json`, (error, stdout, stderr) => {
            if (error) {
                reject(`Error delegating stake: ${stderr}`);
            } else {
                resolve(stdout); // Output from the delegate stake command
            }
        });
    });
}

// Execute the script
(async () => {
    try {
        const running = await isValidatorRunning();
        if (running) {
            console.log('Validator is already running on port 8899.');

            // Run catchup command before delegating stake
            console.log('Running catchup command...');
            const catchupOutput = await runCatchup();
            console.log('Catchup command output:\n', catchupOutput);

            // Check for 'has caught up' in the catchup output
            if (catchupOutput.includes('has caught up')) {
                console.log('Validator caught up, proceeding to delegate stake...');
                const delegateOutput = await delegateStake();
                console.log('Delegate stake command output:\n', delegateOutput);
                console.log('Delegation successful, a restart is required.'); // Message to show after delegation
            } else {
                console.log('Validator did not catch up. No stake delegation attempted. Check logs for fatal errors.');
            }
            return; // Exit the script after handling catchup and delegation
        } else {
            console.log('Validator is not currently running. Proceeding to start it.');
            console.log('Starting the validator now...');
            exec(`cd ${validatorDirectory} && ${startCommand}`, { stdio: 'ignore' }, (error) => {
                if (error) {
                    console.error(`Error starting validator: ${error.message}`);
                    return; // Exit if there was an error starting the validator
                }
                console.log('Validator start command issued.');
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
                    // Countdown for 10 seconds before running the catchup command
                    for (let i = 10; i > 0; i--) {
                        console.log(`Waiting for ${i} seconds for the validator to stabilize...`);
                        await new Promise(res => setTimeout(res, 1000));
                    }
                    // Run catchup command
                    console.log('Running catchup command...');
                    const catchupOutput = await runCatchup();
                    console.log('Catchup command output:\n', catchupOutput);
                    // Check for 'has caught up' in the catchup output
                    if (catchupOutput.includes('has caught up')) {
                        console.log('Validator caught up, delegating stake...');
                        const delegateOutput = await delegateStake();
                        console.log('Delegate stake command output:\n', delegateOutput);
                        console.log('Delegation successful, a restart is required.'); // Message to show after successful delegation
                    } else {
                        console.log('Validator did not catch up. No stake delegation attempted. Check logs for fatal errors.');
                    }
                    return; // Exit the script after handling catchup and delegation
                }
                attempts++;
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
