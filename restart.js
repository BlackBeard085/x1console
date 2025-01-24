const { exec } = require('child_process');
const os = require('os');

// Get the current user's username
const username = os.userInfo().username;

// Define the validator directory based on the current user
const validatorDirectory = `/home/${username}/x1/`;

// Command to stop the validator
const stopCommand = 'solana-validator exit -f';

// New command to start the validator
const startCommand = `~/x1console/./start_validator.sh`;

// Check if the validator is running by checking port 8899
function isValidatorRunning() {
    return new Promise((resolve) => {
        exec("lsof -i :8899", (error, stdout) => {
            resolve(stdout.trim() !== ''); // Resolve true if output is not empty
        });
    });
}

// Function to run solana catchup
function runCatchup(callback, timeoutDuration = 20000) {
    const child = exec('solana catchup --our-localhost');
    let output = '';

    // Set a timeout to handle the case where catchup takes too long
    const timeout = setTimeout(() => {
        console.error('Catchup process timed out. Validator is falling behind.');
        child.kill();
        callback("falling behind", output); // Notify falling behind with accumulated output
    }, timeoutDuration);

    child.stdout.on('data', (data) => {
        output += data; // Accumulate output
        // Log the real-time output to the console
        console.log(data);

        // Check conditions in the output
        if (data.includes('falling behind')) {
            clearTimeout(timeout); // Clear the timeout if we find a falling behind message
            console.log('Falling behind output:\n' + output); // Print the accumulated output
            callback("falling behind", output); // Notify falling behind with the output
            child.kill(); // Kill the child process
        }
    });

    child.stderr.on('data', (data) => {
        console.error(`Error: ${data}`);
        if (data.includes('Connection refused')) {
            clearTimeout(timeout); // Clear the timeout if connection refused
            callback("connection refused", output); // Notify connection refused with output
            child.kill(); // Kill the child process
        }
    });

    child.on('exit', (code) => {
        clearTimeout(timeout); // Clear the timeout
        if (code !== 0) {
            callback("finished", output); // Notify finished with output
        } else {
            callback("successful", output); // Notify successful with output
        }
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
        exec(`${startCommand}`, { stdio: 'ignore' }, (error) => {
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

                console.log('Waiting for snapshot download to complete..');
                await new Promise(res => setTimeout(res, 35000));

                // Countdown for 10 seconds before running the catchup command
                for (let i = 10; i > 0; i--) {
                    console.log(`Waiting for ${i} seconds for the validator to stabilize...`);
                    await new Promise(res => setTimeout(res, 1000));
                }

                // Start trying to catch up with proper connection checks
                let catchupAttempts = 0; // This will be incremented correctly
                const maxCatchupAttempts = 4; // Max number of catchup retries
                const catchupDelay = 25; // Delay in seconds between catchup attempts
                let catchupSuccessful = false;

                while (catchupAttempts < maxCatchupAttempts && !catchupSuccessful) {
                    console.log(`Attempting catchup... (Attempt ${catchupAttempts + 1})`);

                    // Check if the validator is still running before attempting catchup
                    const isStillRunning = await isValidatorRunning();
                    if (!isStillRunning) {
                        console.log('Validator has stopped running. Please check logs for errors and report them to the team. Remove ledger and start validator again.');
                        break; // Exit the loop if the validator is not running
                    }

                    await new Promise((resolve) => {
                        runCatchup((status, output) => {
                            if (status === "falling behind") {
                                console.log('Catchup timeout, Unless you are attempting a cluster restart, your Validator is falling behind, please stop your validator, remove ledger and start validator again.');
                               // console.log('Falling behind output:\n' + output); // Print the accumulated output
                                catchupSuccessful = true; // Exit catchup attempts due to falling behind
                                resolve(); // Complete the catchup promise
                            } else if (status === "connection refused") {
                                // When connection is refused, just log and wait before retrying
                                console.log('Connection refused, checking if Validator is still running...');
                                setTimeout(() => {
                                    resolve(); // Continue the catchup attempts if connection refused
                                }, catchupDelay * 1000);
                            } else if (status === "successful") {
                                catchupSuccessful = true; // Successful completion
                                resolve();
                            } else {
                                resolve(); // To avoid waiting indefinitely
                            }
                        });
                    });

                    // Wait for 20 seconds before the next catchup attempt
                    if (!catchupSuccessful && catchupAttempts < maxCatchupAttempts) {
                        console.log('Validator is still running, retrying catchup in 20 seconds...');
                        await new Promise(res => setTimeout(res, catchupDelay * 1000));
                    }

                    catchupAttempts++; // Increment the attempt number here
                }

                if (catchupSuccessful) {
                    console.log(' ');
                } else {
                    console.log('Failed to start validator successfully.');
                }
                return; // Exit the script after catchup handling
            }

            attempts++;
            console.log(`Check ${attempts}: Validator not yet running...`);
        }

        console.log('Failed to start the validator. Port 8899 is still not in use. Please check logs for errors. Remove ledger and start again.');

    } catch (error) {
        console.error('Failed to manage validator:', error);
    } finally {
        // Ensure the script exits when done
        process.exit();
    }
})();
