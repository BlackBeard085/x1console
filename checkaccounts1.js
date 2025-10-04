const { exec, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Load withdrawerconfig.json to get the keypairPath
const configPath = path.join(__dirname, 'withdrawerconfig.json');
let withdrawerPath = '';

try {
    const configData = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    withdrawerPath = configData.keypairPath;
} catch (err) {
    console.error(`Failed to read or parse withdrawerconfig.json at ${configPath}:`, err);
    process.exit(1);
}

const homeDir = process.env.HOME || process.env.HOMEPATH;
const stakePath = path.join(homeDir, '.config/solana/stake.json');
const votePath = path.join(homeDir, '.config/solana/vote.json');
const identityPath = path.join(homeDir, '.config/solana/identity.json');

const archivePath = path.join(homeDir, '.config/solana/archive');

const walletsDir = path.join(homeDir, 'x1console');
const tachyonDir = path.join(homeDir, 'x1/tachyon');
const walletsFilePath = path.join(walletsDir, 'wallets.json');

if (!fs.existsSync(walletsDir)) {
    fs.mkdirSync(walletsDir, { recursive: true });
}
if (!fs.existsSync(tachyonDir)) {
    fs.mkdirSync(tachyonDir, { recursive: true });
}

let newWalletsCreated = false;

// Utility functions
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

function readWallets() {
    if (fs.existsSync(walletsFilePath)) {
        return JSON.parse(fs.readFileSync(walletsFilePath, 'utf8')) || [];
    }
    return [];
}

function writeWallets(wallets) {
    fs.writeFileSync(walletsFilePath, JSON.stringify(wallets, null, 2));
    fs.copyFileSync(walletsFilePath, path.join(tachyonDir, 'wallets.json'));
    console.log(`wallets.json public addresses updated and copied to: ${tachyonDir}`);
}

function updateWalletEntry(wallets, name, address) {
    const index = wallets.findIndex(w => w.name === name);
    if (index !== -1) {
        wallets[index].address = address;
    } else {
        wallets.push({ name, address });
    }
}

function updateWallets() {
    const files = [withdrawerPath, identityPath, stakePath, votePath];
    const wallets = readWallets();

    try {
        for (const file of files) {
            if (!fs.existsSync(file)) {
                const walletName = capitalizeFirstLetter(path.basename(file, '.json'));
                const existingWallet = wallets.find(w => w.name === walletName);
                if (existingWallet) {
                    console.log(`Skipping ${walletName} as the wallet file does not exist.`);
                }
                continue;
            }
            const pubkey = execSync(`solana-keygen pubkey ${file}`).toString().trim();
            const name = capitalizeFirstLetter(path.basename(file, '.json'));
            const existingWallet = wallets.find(w => w.name === name);
            if (existingWallet) {
                if (existingWallet.address !== pubkey) {
                    updateWalletEntry(wallets, name, pubkey);
                    console.log(`Updated ${name} address in wallets.json.`);
                }
            } else {
                updateWalletEntry(wallets, name, pubkey);
                console.log(`Added ${name} in wallets.json.`);
            }
        }
        writeWallets(wallets);
    } catch (err) {
        console.error(`Error updating wallets.json: ${err}`);
    }
}

// Check if stake account exists and is valid
async function checkStakeAccount() {
    return new Promise((resolve, reject) => {
        let pubkey = '';

        if (fs.existsSync(stakePath)) {
            pubkey = stakePath;
        } else {
            const wallets = readWallets();
            const stakeWallet = wallets.find(w => w.name === 'Stake');
            if (stakeWallet) {
                pubkey = stakeWallet.address;
            } else {
                reject('Stake account file and public key not found.');
                return;
            }
        }

        exec(`solana stake-account ${pubkey}`, (error, stdout, stderr) => {
            if (stderr.includes('AccountNotFound')) {
                resolve(true); // Need to create
            } else if (stderr.includes('is not a stake account')) {
                // Invalid account type, move and recreate
                moveAndCreateStakeAccount().then(resolve).catch(reject);
            } else if (error) {
                reject(`Error checking stake account: ${stderr}`);
            } else {
                resolve(false); // Exists and valid
            }
        });
    });
}

// Check if vote account exists and is valid
async function checkVoteAccount() {
    return new Promise((resolve, reject) => {
        let pubkey = '';

        if (fs.existsSync(votePath)) {
            pubkey = votePath;
        } else {
            const wallets = readWallets();
            const voteWallet = wallets.find(w => w.name === 'Vote');
            if (voteWallet) {
                pubkey = voteWallet.address;
            } else {
                reject('Vote account file and public key not found.');
                return;
            }
        }

        exec(`solana vote-account ${pubkey}`, (error, stdout, stderr) => {
            if (stderr.includes('account does not exist')) {
                resolve(true); // Need to create
            } else if (stderr.includes('is not a vote account')) {
                moveAndCreateVoteAccount().then(resolve).catch(reject);
            } else if (error) {
                reject(`Error checking vote account: ${stderr}`);
            } else {
                resolve(false); // Exists and valid
            }
        });
    });
}

// Functions to create accounts if needed
function moveAndCreateStakeAccount() {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync(archivePath)) {
            fs.mkdirSync(archivePath);
        }
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const archiveFile = path.join(archivePath, `stake-${timestamp}.json`);
        fs.renameSync(stakePath, archiveFile);
        console.log(`Moved old stake.json to archive: ${archiveFile}`);

        exec(`solana-keygen new --no-passphrase -o ${stakePath}`, (err) => {
            if (err) {
                reject(`Error generating new stake key: ${err}`);
                return;
            }
            console.log(`Generated new stake key: ${stakePath}`);
            newWalletsCreated = true;
            exec(`solana create-stake-account ${stakePath} 1`, (err2) => {
                if (err2) {
                    reject(`Error creating stake account: ${err2}`);
                } else {
                    exec(`solana stake-account ${stakePath}`, (err3, stdout) => {
                        if (err3) {
                            reject(`Error checking new stake account: ${err3}`);
                        } else {
                            resolve(`Stake account created: ${stdout}`);
                        }
                    });
                }
            });
        });
    });
}

function moveAndCreateVoteAccount() {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync(archivePath)) {
            fs.mkdirSync(archivePath);
        }
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const archiveFile = path.join(archivePath, `vote-${timestamp}.json`);
        fs.renameSync(votePath, archiveFile);
        console.log(`Moved old vote.json to archive: ${archiveFile}`);

        exec(`solana-keygen new --no-passphrase -o ${votePath}`, (err) => {
            if (err) {
                reject(`Error generating new vote key: ${err}`);
                return;
            }
            console.log(`Generated new vote key: ${votePath}`);
            newWalletsCreated = true;
            exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 5`, (err2) => {
                if (err2) {
                    reject(`Error creating vote account: ${err2}`);
                } else {
                    exec(`solana vote-account ${votePath}`, (err3, stdout) => {
                        if (err3) {
                            reject(`Error checking new vote account: ${err3}`);
                        } else {
                            resolve(`Vote account created: ${stdout}`);
                        }
                    });
                }
            });
        });
    });
}

// Main execution: sequentially check and create if needed
async function main() {
    updateWallets();

    try {
        const needStake = await checkStakeAccount();
        if (needStake) {
            console.log('Creating stake account...');
            await moveAndCreateStakeAccount();
        } else {
            console.log('Stake account exists and is valid.');
        }

        const needVote = await checkVoteAccount();
        if (needVote) {
            console.log('Creating vote account...');
            await moveAndCreateVoteAccount();
        } else {
            console.log('Vote account exists and is valid.');
        }

        // Update wallets.json with latest addresses
        createWalletsJSON();
    } catch (err) {
        console.error(`Error: ${err}`);
    }
}

function createWalletsJSON() {
    if (!newWalletsCreated) {
        console.log('No new wallets were created; wallets.json not updated.');
        return;
    }
    const wallets = [
        { name: 'Id', address: execSync(`solana-keygen pubkey ${withdrawerPath}`).toString().trim() },
        { name: 'Identity', address: execSync(`solana-keygen pubkey ${identityPath}`).toString().trim() },
        { name: 'Stake', address: execSync(`solana-keygen pubkey ${stakePath}`).toString().trim() },
        { name: 'Vote', address: execSync(`solana-keygen pubkey ${votePath}`).toString().trim() },
    ];
    writeWallets(wallets);
}

// Run the main function
main();
