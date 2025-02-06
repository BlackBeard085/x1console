const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logFilePath = path.join(process.env.HOME, 'x1', 'log.txt');
const autoConfigFilePath = path.join(process.env.HOME, 'x1console', 'autoconfig'); // Path to the autoconfig file

// Function to print the console version
function printConsoleVersion() {
    console.log('X1Console v0.1.02  -  The BlackPearl by BlackBeard_85');
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
        const hasBeenModifiedRecently = (currentTime - fileModifiedTime < 7000); // 7 seconds threshold

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
                try {
                    const autoConfigContent = fs.readFileSync(autoConfigFilePath, 'utf8').trim();
                    console.log(`- Autopilot: ${autoConfigContent}`);
                } catch (err) {
                    console.error(`Error reading autoconfig: ${err.message}`);
                }
                break; // Exit loop once we find and output the status
            }
        }
    });
}

// Check the log file status
checkLogFileModification();
