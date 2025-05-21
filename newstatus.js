const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const logFilePath = path.join(process.env.HOME, 'x1', 'log.txt');
const autoConfigFilePath = path.join(process.env.HOME, 'x1console', 'autoconfig'); // Path to the autoconfig file
const withdrawerConfigFilePath = path.join(process.env.HOME, 'x1console', 'withdrawerconfig.json'); // Path to the withdrawer config file
const restartCountFilePath = path.join(process.env.HOME, 'x1console', 'restart_count.log'); // Path to the restart count log

// Variables to store cronjob presence
let isAutostakerActive = false;
let isAutopingerActive = false;
let isAutoupdaterActive = false;

// Function to print the console version
function printConsoleVersion() {
    console.log('X1Console v0.1.33  -  The BlackPearl by BlackBeard_85');
}

// Check for specific cronjobs
function checkCronJobs() {
    exec('crontab -l', (error, stdout, stderr) => {
        if (error) {
            // Likely no crontab exists or error, assume none
            isAutostakerActive = false;
            isAutopingerActive = false;
            isAutoupdaterActive = false;
            return;
        }
        // Search for the specific autostaker cron line
        const autostakerLine = '0 18 * * 1,3,6 cd ~/x1console/ && ./autostaker.sh';
        if (stdout.includes(autostakerLine)) {
            isAutostakerActive = true;
        }
        // Search for the specific autopinger cron line
        const autopingerLine = '0 * * * * cd ~/x1console/ && ./autopinger.sh';
        if (stdout.includes(autopingerLine)) {
            isAutopingerActive = true;
        }
        // Search for the specific autoupdater cron line
        const autoupdaterLine = '0 * * * * cd ~/x1console/ && ./autoupdater.sh';
        if (stdout.includes(autoupdaterLine)) {
            isAutoupdaterActive = true;
        }
    });
}

// Function to check if the log file is being modified
function checkLogFileModification() {
    fs.stat(logFilePath, (err, stats) => {
        if (err) {
            console.log('Active Status will show once Validator starts');
            checkValidatorStatus();
            return;
        }

        const currentTime = Date.now();
        const fileModifiedTime = new Date(stats.mtime).getTime();
        const hasBeenModifiedRecently = (currentTime - fileModifiedTime < 3000); // 3 seconds threshold

        if (hasBeenModifiedRecently) {
            console.log('- Logs: Running');
        } else {
            console.log('- Logs: Stopped');
        }

        // Proceed to check validator status
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

        // Parse output for status
        const lines = stdout.split('\n');
        for (let line of lines) {
            if (line.includes('- Status:')) {
                // Output the status line
                console.log(line.trim());

                // Read autoconfig content
                let autoConfigContent = '-';
                try {
                    autoConfigContent = fs.readFileSync(autoConfigFilePath, 'utf8').trim();
                } catch (err) {
                    // Use default if error
                }

                let autopilotOutput = `- Autopilot: ${autoConfigContent}`;
                if (autoConfigContent === 'ON') {
                    // Read restart count
                    let restartCountContent = '-';
                    try {
                        restartCountContent = fs.readFileSync(restartCountFilePath, 'utf8').trim();
                    } catch (err) {
                        // default
                    }
                    autopilotOutput += `       48Hrs auto-restarts: ${restartCountContent}`;

                    // Append 'Auto-staker active' if applicable
                    if (isAutostakerActive) {
                        autopilotOutput += `\nAuto-staker active`;
                    }

                    // Append 'Auto-pinger active' if applicable
                    if (isAutopingerActive) {
                        autopilotOutput += `\           Auto-pinger active`;
                    }
                    // Append 'Auto-pinger active' if applicable
                    if (isAutoupdaterActive) {
                        autopilotOutput += `\           Auto-updater active`;
                    }
                }

                console.log(autopilotOutput);

                // Read and output withdrawer config
                try {
                    const withdrawerConfigContent = fs.readFileSync(withdrawerConfigFilePath, 'utf8');
                    const withdrawerConfig = JSON.parse(withdrawerConfigContent);
                    const currentWithdrawer = withdrawerConfig.keypairPath;
                    console.log(`- Current set Withdrawer: ${currentWithdrawer}`);
                } catch (err) {
                    // ignore errors
                }
                break; // exit loop after output
            }
        }
    });
}

// Main execution
printConsoleVersion();
checkCronJobs();

// Delay to allow cron check to finish before proceeding
setTimeout(() => {
    checkLogFileModification();
}, 500);
