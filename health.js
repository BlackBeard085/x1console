const fs = require('fs');
const { exec } = require('child_process');
const colors = require('colors'); // Import colors

// ANSI Escape Codes
const ORANGE = '\x1b[38;5;214m'; // A custom ANSI escape code for orange
const RESET = '\x1b[0m'; // To reset the color

// Load wallet addresses from a JSON file
function loadWallets() {
    const CONFIG_FILE = 'wallets.json';
    if (fs.existsSync(CONFIG_FILE)) { // Check if the file exists
        try {
            const data = fs.readFileSync(CONFIG_FILE); // Read the file
            return JSON.parse(data); // Parse the JSON data into an object
        } catch (error) {
            console.error('Error reading wallets.json:', error.message);
            return null; // Return null if there is an error
        }
    } else {
        console.error(`${CONFIG_FILE} does not exist.`);
        return null; // Return null if file does not exist
    }
}

// Function to check validator health with shell command
async function checkValidatorHealth(identityAddress) {
    try {
        const command = `solana validators | grep ${identityAddress}`; // Command to check validator info
        const validatorInfo = await new Promise((resolve, reject) => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    resolve(''); // Resolve to an empty string instead, to handle this case gracefully.
                    return;
                }
                resolve(stdout); // Resolve with standard output if successful
            });
        });

        // Output the raw validator information
        if (validatorInfo) {
            console.log(`Raw Validator Information:\n${validatorInfo}`);

            // Determine if the validator is delinquent by looking for "⚠️"
            const isDelinquent = validatorInfo.includes('⚠️');
            const status = isDelinquent ? 'Delinquent'.red : 'Active'.green; // Use colors to color the status

            // Output validator health report
            console.log(`Validator Health Report for Identity: ${identityAddress}`);
            console.log(`- Status: ${status}`);

            if (isDelinquent) {
                console.log(`${ORANGE}WARNING! Validator is delinquent. ACTION REQUIRED.${RESET}`); 
            }
        } else {
            // If no information is returned for the validator
            const delinquentStatus = 'Delinquent'.red;
            console.log(`Validator Health Report for Identity: ${identityAddress}`);
            console.log(`- Status: ${delinquentStatus}`);
            console.log(`${ORANGE}WARNING! Identity address was not found on X1 validators.${RESET}`);
        }
        console.log();
    } catch (error) {
        console.error('Error fetching validator information:', error);
    }
}

// Main function to run the program
async function main() {
    const wallets = loadWallets(); // Load wallet addresses from JSON file
    if (wallets) {
        const identityWallet = wallets.find(wallet => wallet.name === 'Identity'); // Find the Identity wallet

        if (identityWallet) {
            await checkValidatorHealth(identityWallet.address); // Check the validator health
        } else {
            console.error('Identity wallet not found in wallets.json');
        }
    } else {
        console.error('No wallets found. Please run Check Balances first.');
    }
}

// Start the program
main().catch(console.error); // Handle errors globally for the main execution.
