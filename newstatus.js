const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logFilePath = path.join(process.env.HOME, 'x1', 'log.txt');

// Function to check if the log file is being modified
function checkLogFileModification() {
    fs.stat(logFilePath, (err, stats) => {
        if (err) {
            console.error(`Error reading file: ${err}`);
            return;
        }

        const currentTime = Date.now();
        const fileModifiedTime = new Date(stats.mtime).getTime();
        const hasBeenModifiedRecently = (currentTime - fileModifiedTime < 10000); // 10 seconds threshold

        if (hasBeenModifiedRecently) {
            console.log('- Logs: Running');
        } else {
            console.log('- Logs: Stopped');
        }
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
                // Output only the status line
                console.log(line.trim());
                break; // Exit loop once we find and output the status
            }
        }
    });
}

// Check the log file status
checkLogFileModification();
// Check the validator status
checkValidatorStatus();
