const fs = require('fs');
const { exec } = require('child_process'); // for executing shell commands
const { Connection, PublicKey } = require('@solana/web3.js');
const readline = require('readline');
const path = require('path'); // for handling file paths
const os = require('os'); // for getting home directory
const SOLANA_CLUSTER = 'https://rpc.testnet.x1.xyz'; // Change to your desired cluster (mainnet, testnet, etc.)
const CONFIG_FILE = 'wallets.json'; // JSON file to store wallet addresses
const TRANSFER_AMOUNT = 1; // Amount in XNT to transfer when funding

// Set up readline to get user input
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Function to ask for wallet address input
async function askForWalletAddress(name) {
    return new Promise((resolve) => {
        rl.question(`Please enter the address for ${name} wallet: `, (address) => {
            resolve(address);
        });
    });
}

// Function to save wallet addresses to a JSON file
async function saveWallets(wallets) {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(wallets, null, 2));
    console.log('Wallet addresses saved to wallets.json');
}

// Function to load wallet addresses from a JSON file
function loadWallets() {
    if (fs.existsSync(CONFIG_FILE)) {
        const data = fs.readFileSync(CONFIG_FILE);
        return JSON.parse(data);
    }
    return null;
}

// Function to attempt to load wallets from an alternative directory
function loadWalletsFromBackup() {
    const backupPath = path.join(os.homedir(), 'x1/tachyon', CONFIG_FILE);
    if (fs.existsSync(backupPath)) {
        console.log(`Found ${CONFIG_FILE} in backup directory. Copying to current directory...`);
        fs.copyFileSync(backupPath, CONFIG_FILE);
        console.log(`${CONFIG_FILE} copied to current directory.`);
        return loadWallets(); // Load the wallets after copying
    }
    return null;
}

// Function to get balances of the wallets
async function getBalances(wallets) {
    const connection = new Connection(SOLANA_CLUSTER, 'confirmed');
    for (const wallet of wallets) {
        try {
            const publicKey = new PublicKey(wallet.address);
            const balance = await connection.getBalance(publicKey);
            console.log(`Wallet: ${wallet.name} (${wallet.address})\nBalance: ${(balance / 1e9).toFixed(2)} XNT\n`); // Balance on the next line
            wallet.balance = balance / 1e9; // Store the balance in XNT for later checks
        } catch (error) {
            console.error(`Error retrieving balance for wallet ${wallet.address}:`, error);
        }
    }
}

// Function to transfer XNT between wallets
function transferSOL(fromWallet, toWallet, amount) {
    return new Promise((resolve, reject) => {
        exec(`solana transfer ${toWallet} ${amount} --allow-unfunded-recipient`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing transfer: ${stderr}`);
                return reject(stderr);
            }
            console.log(stdout);
            resolve();
        });
    });
}

// Main function to run the program
async function main() {
    let wallets = loadWallets();
    if (!wallets) {
        console.log(`No wallet addresses found in current directory. Looking for ${CONFIG_FILE} in backup directory...`);
        wallets = loadWalletsFromBackup();
    }

    if (!wallets) {
        console.log('No wallet addresses found. You will be prompted to enter them.');
        wallets = [
            { name: 'Id', address: await askForWalletAddress('Id') },
            { name: 'Identity', address: await askForWalletAddress('Identity') },
            { name: 'Stake', address: await askForWalletAddress('Stake') },
            { name: 'Vote', address: await askForWalletAddress('Vote') },
        ];
        rl.close(); // Close the readline interface
        await saveWallets(wallets);
    } else {
        console.log('Loaded wallet addresses from wallets.json:');
        wallets.forEach(wallet => {
            console.log(`- ${wallet.name}: ${wallet.address}`);
        });
    }
    
    await getBalances(wallets);

    const idWallet = wallets.find(w => w.name === 'Id');
    const identityWallet = wallets.find(w => w.name === 'Identity');
    const stakeWallet = wallets.find(w => w.name === 'Stake');
    
    // Check balances of Identity and Stake wallets
    const needsFunding = [];
    
    if (identityWallet.balance < 1) {
        needsFunding.push(identityWallet);
    }
    if (stakeWallet.balance < 1) {
        needsFunding.push(stakeWallet);
    }

    // If any wallets need funding
    if (needsFunding.length > 0) {
        // Check if the Id wallet has enough balance for the transfers
        if (idWallet.balance >= needsFunding.length * TRANSFER_AMOUNT) {
            // Loop through the wallets that need funding and transfer 1 XNT to each
            for (const wallet of needsFunding) {
                console.log(`\nSending ${TRANSFER_AMOUNT} XNT to ${wallet.address}`);
                await transferSOL(idWallet.address, wallet.address, TRANSFER_AMOUNT);
            }
            console.log(`\nChecking balances again...`);
            await getBalances(wallets);

            // Final check to see if both accounts are now funded
            if (identityWallet.balance >= 1 && stakeWallet.balance >= 1) {
                console.log("Accounts well funded");
                process.exit(0);
            }
        } else {
            console.log("Not enough funds in the Id wallet to perform the transfers.");
            process.exit(1);
        }
    } else {
        console.log("Accounts well funded");
        process.exit(0);
    }
}

// Start the program
main();
