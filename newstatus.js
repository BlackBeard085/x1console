const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

const execAsync = util.promisify(exec);
const statAsync = util.promisify(fs.stat);
const readFileAsync = util.promisify(fs.readFile);

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
    console.log('X1Console v1.0.3  -  The BlackPearl by BlackBeard_85');
}

// Asynchronous function to check for specific cronjobs
async function checkCronJobs() {
    try {
        const { stdout } = await execAsync('crontab -l');

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
    } catch (error) {
        // Likely no crontab exists or error, assume none
        isAutostakerActive = false;
        isAutopingerActive = false;
        isAutoupdaterActive = false;
    }
}

// Asynchronous function to check if the log file is being modified
async function checkLogFileModification() {
    try {
        const stats = await statAsync(logFilePath);
        const currentTime = Date.now();
        const fileModifiedTime = new Date(stats.mtime).getTime();
        const hasBeenModifiedRecently = (currentTime - fileModifiedTime < 3000); // 3 seconds threshold

        if (hasBeenModifiedRecently) {
            console.log('- Logs: Running');
        } else {
            console.log('- Logs: Stopped');
        }
    } catch (err) {
        console.log('Active Status will show once Validator starts');
    }
}

// Asynchronous function to check validator/system status
async function checkValidatorStatus() {
    try {
        const { stdout, stderr } = await execAsync('node health.js');

        if (stderr) {
            //console.error(`${stderr}`);
            return;
        }

        const lines = stdout.split('\n');
        for (let line of lines) {
            if (line.includes('- Status:')) {
                // Output the status line
                console.log(line.trim());

                // Read autoconfig content
                let autoConfigContent = '-';
                try {
                    autoConfigContent = (await readFileAsync(autoConfigFilePath, 'utf8')).trim();
                } catch (err) {
                    // Use default if error
                }

                let autopilotOutput = `- Autopilot: ${autoConfigContent}`;
                if (autoConfigContent === 'ON') {
                    // Read restart count
                    let restartCountContent = '-';
                    try {
                        restartCountContent = (await readFileAsync(restartCountFilePath, 'utf8')).trim();
                    } catch (err) {
                        // default
                    }
                    autopilotOutput += `       48Hrs auto-restarts: ${restartCountContent}\n`;

                    // Append 'Auto-staker active' if applicable
                    if (isAutoupdaterActive) {
                        autopilotOutput += `Auto-updater active`;
                    }

                    // Append 'Auto-pinger active' if applicable
                    if (isAutopingerActive) {
                        autopilotOutput += `\           Auto-pinger active`;
                    }
                    // Append 'Auto-updater active' if applicable
                    if (isAutostakerActive) {
                        autopilotOutput += `\           Auto-staker active`;
                    }
                }

                console.log(autopilotOutput);

                // Read and output withdrawer config
                try {
                    const withdrawerConfigContent = await readFileAsync(withdrawerConfigFilePath, 'utf8');
                    const withdrawerConfig = JSON.parse(withdrawerConfigContent);
                    const currentWithdrawer = withdrawerConfig.keypairPath;
                    console.log(`- Current set Withdrawer: ${currentWithdrawer}`);
                } catch (err) {
                    // ignore errors
                }
                break; // exit loop after output
            }
        }
    } catch (err) {
        console.error(`Error executing health.js: ${err.message}`);
    }
}

// Main execution
async function main() {
    printConsoleVersion();

    // Run checks concurrently
    await Promise.all([
        checkCronJobs(),
        checkLogFileModification(),
        checkValidatorStatus()
    ]);
}

// Invoke main
main();
