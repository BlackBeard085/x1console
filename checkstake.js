const fs = require('fs');
const { exec } = require('child_process');

// ANSI escape codes for colors
const ANSI_ORANGE = '\x1b[38;5;214m'; // Orange color for the zero active stake message
const ANSI_RESET = '\x1b[0m'; // Reset to default color

// Load wallet addresses from a JSON file
function loadWallets() {
    const CONFIG_FILE = 'wallets.json';
    if (fs.existsSync(CONFIG_FILE)) {
        try {
            const data = fs.readFileSync(CONFIG_FILE);
            return JSON.parse(data);
        } catch (error) {
            console.error('Error reading wallets.json:', error.message);
            return null;
        }
    } else {
        console.error(`${CONFIG_FILE} does not exist.`);
        return null;
    }
}

// Function to check stake information with shell command
async function checkStake(voteAddress) {
    try {
        const command = `solana stakes ${voteAddress}`;
        const stakeInfo = await new Promise((resolve, reject) => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error('Error executing command:', stderr);
                    resolve(''); // Resolve to an empty string
                    return;
                }
                resolve(stdout); // Resolve with standard output
            });
        });

        // Output the specific Active Stake information
        if (stakeInfo) {
            const lines = stakeInfo.split('\n'); // Split the output into lines
            const activeStakeLines = lines.filter(line => line.includes('Active Stake:')); // Filter for active stake lines
            
            let totalActiveStake = 0;

            if (activeStakeLines.length > 0) {
                console.log(`Active Stake Information for Vote Address: ${voteAddress}\n`);
                
                activeStakeLines.forEach(line => {
                    console.log(line); // Print each line that contains "Active Stake"
                    const match = line.match(/Active Stake:\s*([\d.]+)/); // Match the active stake amount

                    if (match) {
                        totalActiveStake += parseFloat(match[1]); // Convert to number and add to total
                    }
                });

                console.log(`\nTotal Active Stake: ${totalActiveStake.toFixed(6)} SOL`); // Print total active stake
                
                // Determine the message based on the total active stake
                if (totalActiveStake === 0) {
                    console.log(`${ANSI_ORANGE}You have 0 active stake.${ANSI_RESET}`); // Print in orange
                } else {
                    console.log("You have active stake."); // Default color
                }
            } else {
                // When no active stake lines found
                console.log(`No stake information found for Vote Address: ${voteAddress}`);
                console.log(`${ANSI_ORANGE}You have 0 active stake.${ANSI_RESET}`); // Print in orange
            }
        } else {
            console.log(`No stake information found for Vote Address: ${voteAddress}`);
            console.log(`${ANSI_ORANGE}You have 0 active stake.${ANSI_RESET}`); // Print in orange
        }
    } catch (error) {
        console.error('Error fetching stake information:', error);
    }
}

// Main function to run the program
async function main() {
    const wallets = loadWallets();
    if (wallets) {
        const voteWallet = wallets.find(wallet => wallet.name === 'Vote');
        if (voteWallet) {
            await checkStake(voteWallet.address);
        } else {
            console.error('Vote wallet not found in wallets.json');
        }
    } else {
        console.error('No wallets found. Please run the getbalances.js script first.');
    }
}

// Start the program
main().catch(console.error);
