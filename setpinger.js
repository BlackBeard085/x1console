const { exec, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const homeDir = process.env.HOME || process.env.USERPROFILE; // Get the user's home directory
const pingerDir = path.join(homeDir, "pinger");

// Function to execute a shell command and return a Promise
function execCommand(command, cwd) {
    return new Promise((resolve, reject) => {
        exec(command, { cwd }, (error, stdout, stderr) => {
            if (error) {
                return reject(`Error: ${stderr}`);
            }
            resolve(stdout.trim());
        });
    });
}

// Function to check if directory exists and remove it
async function validateAndRemoveDirectory(directory) {
    if (fs.existsSync(directory)) {
        console.log("Removing existing pinger directory...");
        fs.rmSync(directory, { recursive: true, force: true });
    }
}

(async () => {
    try {
        // Step 1: Validate and potentially remove existing pinger directory
        await validateAndRemoveDirectory(pingerDir);

        // Step 2: Clone the repository
        console.log("Cloning the repository...");
        await execCommand("git clone https://github.com/jacklevin74/pinger.git", homeDir);

        // Step 3: Install necessary packages
        console.log("Installing packages...");
        await execCommand("npm install express child_process", pingerDir);

        // Step 4: Start the server in a detached mode
        console.log("Starting the server...");
        const serverProcess = spawn("npm", ["start"], {
            cwd: pingerDir,
            detached: true,
            stdio: "ignore" // Ignore output
        });

        // Detach the child process from the parent process
        serverProcess.unref();

        console.log("Pinger has started and is running in the background.");

        // Gracefully close the script with no further output
        process.exit(0);

    } catch (error) {
        console.error(error);
    }
})();
