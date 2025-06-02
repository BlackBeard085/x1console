const { exec } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');

// Get the current user's username
const username = os.userInfo().username;
// Define the validator directory
const validatorDirectory = `~/x1/tachyon`;
const walletsDirectory = `~/x1console/wallets.json`;

// Command to start the validator
const startCommand = `./start_validator.sh`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
        });
    });
}

// Function to run Solana catchup
async function runCatchup() {
    while (true) {
        try {
            console.log('');
            console.log("Executing catchup command...");
            const output = await new Promise((resolve, reject) => {
                exec('solana catchup --our-localhost', (error, stdout, stderr) => {
                    if (error) {
                        reject(`Error running catchup: ${stderr.trim()}`);
                    } else {
                        resolve(stdout.trim()); // Output from the catchup command
                    }
                });
            });

            console.log('Catchup command output:\n', output);

            // Check for outputs
            if (output.includes('has caught up')) {
                console.log('');
                console.log('Catchup successful: Validator has caught up.');
                return output; // Return the output if caught up
            } else if (output.includes('Connection refused')) {
                console.log('Connection refused. Checking if the validator is still running...');

                // Check if the validator is running and wait if it's still running
                for (let attempt = 0; attempt < 5; attempt++) {  // Try 5 times
                    const running = await isValidatorRunning();
                    if (running) {
                        console.log('');
                        console.log('Validator is still running. Waiting for 10 seconds before trying catchup again...');
                        await new Promise(res => setTimeout(res, 10000)); // Wait for 10 seconds
                        console.log('Retrying catchup command...');
                        break; // Exit retry loop
                    } else {
                        console.log('Validator is not running. Exiting catchup.');
                        throw new Error('Validator is not running.');
                    }
                }
            } else {
                console.log('Unexpected output from catchup command. Checking again...');
                await new Promise(res => setTimeout(res, 10000)); // Wait for 10 seconds
            }
        } catch (error) {
            console.error('Error during catchup:', error);
            await new Promise(res => setTimeout(res, 10000)); // Wait for 10 seconds before retrying
        }
    }
}

// Function to read wallet addresses from wallets.json
function readWallets() {
    const walletsPath = path.join(os.homedir(), 'x1console', 'wallets.json');
    if (!fs.existsSync(walletsPath)) {
        throw new Error(`Wallets file not found: ${walletsPath}`);
    }
    const walletsData = fs.readFileSync(walletsPath);
    const wallets = JSON.parse(walletsData);
    let stakeAddress, voteAddress;

    wallets.forEach(wallet => {
        if (wallet.name === 'Stake') {
            stakeAddress = wallet.address;
        } else if (wallet.name === 'Vote') {
            voteAddress = wallet.address;
        }
    });

    if (!stakeAddress || !voteAddress) {
        throw new Error('Stake or Vote wallet address not found in wallets.json');
    }

    return { stakeAddress, voteAddress };
}

// Function to delegate stake using wallet addresses
async function delegateStake() {
    const { stakeAddress, voteAddress } = readWallets();
    return new Promise((resolve, reject) => {
        exec(`cd ${validatorDirectory} && solana delegate-stake ${stakeAddress} ${voteAddress}`, (error, stdout, stderr) => {
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
        const running = await isValidatorRunning();
        if (running) {
            console.log('');
            console.log('Validator is already running on port 8899.');

            // Run catchup command before delegating stake
            console.log('Running catchup command...');
            const catchupOutput = await runCatchup();

            // Proceed to delegate stake
            const delegateOutput = await delegateStake();
            console.log('');
            console.log('Delegate stake command output:\n', delegateOutput);
            console.log('Delegation successful, stake has been activated.'); // Message to show after delegation
            return; // Exit the script after handling catchup and delegation
        } else {
            console.log('');
            console.log('Validator is not currently running. Proceeding to start it.');
            console.log('Starting the validator now...');
            console.log('');
            exec(`${startCommand}`, { stdio: 'pipe' }, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error starting validator: ${stderr.trim()}`);
                    return; // Exit if there was an error starting the validator
                }
                console.log('Validator start command issued.');
            });

            // Check if the validator has started successfully
            for (let attempt = 0; attempt < 10; attempt++) {
                await new Promise(res => setTimeout(res, 10000)); // Wait for 10 seconds before checking
                const isRunning = await isValidatorRunning();
                if (isRunning) {
                    console.log('');
                    console.log('Validator started successfully and is running on port 8899.');
                    // Countdown for 10 seconds before running the catchup command
                    for (let i = 10; i > 0; i--) {
                        console.log('');
                        console.log(`Waiting for ${i} seconds for the validator to stabilize...`);
                        await new Promise(res => setTimeout(res, 1000));
                    }
                    // Run catchup command
                    console.log('Running catchup command...');
                    const catchupOutput = await runCatchup();
                    // Proceed to delegate stake
                    const delegateOutput = await delegateStake();
                    console.log('Delegate stake command output:\n', delegateOutput);
                    console.log('Delegation successful, a restart is required.'); // Message to show after successful delegation
                    return; // Exit the script after handling catchup and delegation
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
