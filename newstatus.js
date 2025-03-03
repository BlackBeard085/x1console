const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logFilePath = path.join(process.env.HOME, 'x1', 'log.txt');
const autoConfigFilePath = path.join(process.env.HOME, 'x1console', 'autoconfig'); // Path to the autoconfig file
const withdrawerConfigFilePath = path.join(process.env.HOME, 'x1console', 'withdrawerconfig.json'); // Path to the withdrawer config file
const restartCountFilePath = path.join(process.env.HOME, 'x1console', 'restart_count.log'); // Path to the restart count log

// Function to print the console version
function printConsoleVersion() {
    console.log('X1Console v0.1.19  -  The BlackPearl by BlackBeard_85');
}

printConsoleVersion();

// Function to check if the log file is being modified
function checkLogFileModification() {
    fs.stat(logFilePath, (err, stats) => {
        if (err) {
            console.log('Active Status will show once Validator starts');
            return; // Stop the script if the log file is not found
        }

        const currentTime = Date.now();
        const fileModifiedTime = new Date(stats.mtime).getTime();
        const hasBeenModifiedRecently = (currentTime - fileModifiedTime < 3000); // 3 seconds threshold

        if (hasBeenModifiedRecently) {
            console.log('- Logs: Running');
        } else {
            console.log('- Logs: Stopped');
        }

        // If the log file exists, proceed to check validator status
        checkValidatorStatus();
    });
}

// Function to check validator status
function checkValidatorStatus() {
    // Execute the health.js script
    exec('node health.js', (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing health.js: ${error.message}`);
            return;
        }

        if (stderr) {
            console.error(`Error in health.js: ${stderr}`);
            return;
        }

        // Split the output into lines and look for the line with "Status:"
        const lines = stdout.split('\n');
        for (let line of lines) {
            if (line.includes('- Status:')) {
                // Output the status line
                console.log(line.trim());

                // Check if the autoconfig file exists and read its content
                let autoConfigContent = '-'; // Default value if the file does not exist
                try {
                    autoConfigContent = fs.readFileSync(autoConfigFilePath, 'utf8').trim();
                } catch (err) {
                    // Suppress error message and use default value
                }

                let autopilotOutput = `- Autopilot: ${autoConfigContent}`;
                if (autoConfigContent === 'ON') {
                    // If autoconfig is ON, read the restart count
                    let restartCountContent = '-'; // Default value if the file does not exist
                    try {
                        restartCountContent = fs.readFileSync(restartCountFilePath, 'utf8').trim();
                    } catch (err) {
                        // Suppress error message and use default value
                    }
                    autopilotOutput += `       48Hrs auto-restarts: ${restartCountContent}`;
                }

                console.log(autopilotOutput);

                // Read the withdrawer configuration
                try {
                    const withdrawerConfigContent = fs.readFileSync(withdrawerConfigFilePath, 'utf8');
                    const withdrawerConfig = JSON.parse(withdrawerConfigContent);
                    const currentWithdrawer = withdrawerConfig.keypairPath;

                    console.log(`- Current set Withdrawer: ${currentWithdrawer}`);
                } catch (err) {
                    // Suppress error message for withdrawer config
                }
                break; // Exit loop once we find and output the status
            }
        }
    });
}

// Check the log file status
checkLogFileModification();
