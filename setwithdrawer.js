const { exec } = require('child_process');
const path = require('path');
const os = require('os');

// Define the expected keypair path
const expectedKeypairPath = path.join(os.homedir(), '.config', 'solana', 'id.json');

// Function to execute a shell command
const runCommand = (command) => {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing command: ${stderr}`);
            }
            resolve(stdout);
        });
    });
};

const checkSolanaConfig = async () => {
    try {
        // Get the solana config
        const configOutput = await runCommand('solana config get');
        
        // Check if the output contains the expected keypair path
        if (configOutput.includes(`Keypair Path:`) && configOutput.includes(expectedKeypairPath)) {
            console.log('withdrawer is set');
        } else {
            console.log('setting to withdrawer');
            await runCommand(`solana config set -k ${expectedKeypairPath}`);
            console.log('Wallet has been set to withdrawer');
        }
    } catch (error) {
        console.error(error);
    }
};

// Run the check
checkSolanaConfig();
