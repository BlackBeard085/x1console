const { exec } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

// Path to the withdrawer config
const configFilePath = path.join(__dirname, 'withdrawerconfig.json');

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

// Function to read the keypair path from config file
const getKeypairPath = () => {
    const configData = fs.readFileSync(configFilePath);
    const config = JSON.parse(configData);
    return config.keypairPath;
};

const checkSolanaConfig = async () => {
    try {
        const expectedKeypairPath = getKeypairPath();
        const configOutput = await runCommand('solana config get');

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
