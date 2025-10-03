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

function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

function updateWalletEntry(wallets, name, address) {
    const index = wallets.findIndex(w => w.name === name);
    if (index !== -1) {
        wallets[index].address = address;
    } else {
        wallets.push({ name, address });
    }
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

function updateWallets() {
    const files = [withdrawerPath, identityPath, stakePath, votePath];
    const wallets = readWallets();

    try {
        for (const file of files) {
            if (!fs.existsSync(file)) {
                const walletName = capitalizeFirstLetter(path.basename(file, '.json'));
                const existingWallet = wallets.find(wallet => wallet.name === walletName);
                if (existingWallet) {
                    console.log(`Skipping ${walletName} as the wallet file does not exist.`);
                    continue;
                }
                continue;
            }
            const publicKey = execSync(`solana-keygen pubkey ${file}`).toString().trim();
            const walletName = capitalizeFirstLetter(path.basename(file, '.json'));
            const existingWallet = wallets.find(wallet => wallet.name === walletName);
            if (existingWallet) {
                if (existingWallet.address === publicKey) {
                    console.log(`Skipping ${walletName} as it already exists in wallets.json.`);
                    continue;
                } else {
                    updateWalletEntry(wallets, walletName, publicKey);
                    console.log(`Updated ${walletName} address in wallets.json.`);
                }
            } else {
                updateWalletEntry(wallets, walletName, publicKey);
                console.log(`Added new wallet entry for ${walletName} in wallets.json.`);
            }
        }
        writeWallets(wallets);
    } catch (error) {
        console.error(`Error updating wallets.json: ${error}`);
    }
}

function moveAndCreateStakeAccount() {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync(archivePath)) {
            fs.mkdirSync(archivePath);
        }
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const newStakePath = path.join(archivePath, `stake-${timestamp}.json`);
        fs.rename(stakePath, newStakePath, (err) => {
            if (err) {
                reject(`Error moving stake account to archive: ${err}`);
                return;
            }
            console.log(`Moved stake.json to archive: ${newStakePath}`);
            exec(`solana-keygen new --no-passphrase -o ${stakePath}`, (keygenError) => {
                if (keygenError) {
                    reject(`Error creating new stake account: ${keygenError}`);
                    return;
                }
                console.log(`Created new stake account: ${stakePath}`);
                newWalletsCreated = true;
                exec(`solana create-stake-account ${stakePath} 1`, (createErr) => {
                    if (createErr) {
                        reject(`Error creating stake account: ${createErr}`);
                        return;
                    }
                    exec(`solana stake-account ${stakePath}`, (checkError, checkStdout) => {
                        if (checkError) {
                            reject(`Error checking new stake account: ${checkError}`);
                            return;
                        }
                        const outputLines = checkStdout.split('\n').slice(0, 10).join('\n');
                        resolve(`New stake account exists:\n${outputLines}`);
                    });
                });
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
        const newVotePath = path.join(archivePath, `vote-${timestamp}.json`);
        fs.rename(votePath, newVotePath, (err) => {
            if (err) {
                reject(`Error moving vote account to archive: ${err}`);
                return;
            }
            console.log(`Moved vote.json to archive: ${newVotePath}`);
            exec(`solana-keygen new --no-passphrase -o ${votePath}`, (keygenError) => {
                if (keygenError) {
                    reject(`Error creating new vote account: ${keygenError}`);
                    return;
                }
                console.log(`Created new vote account: ${votePath}`);
                newWalletsCreated = true;
                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 5`, (createError) => {
                    if (createError) {
                        reject(`Error creating vote account: ${createError}`);
                        return;
                    }
                    exec(`solana vote-account ${votePath}`, (checkError, checkStdout) => {
                        if (checkError) {
                            reject(`Error checking new vote account: ${checkError}`);
                            return;
                        }
                        const outputLines = checkStdout.split('\n').slice(0, 10).join('\n');
                        resolve(`New vote account exists:\n${outputLines}`);
                    });
                });
            });
        });
    });
}

function checkStakeAccount() {
    return new Promise(async (resolve, reject) => {
        let publicKey;
        if (fs.existsSync(stakePath)) {
            publicKey = stakePath;
        } else {
            const existingWallets = readWallets();
            const existingStake = existingWallets.find(wallet => wallet.name === capitalizeFirstLetter("stake"));
            if (existingStake) {
                publicKey = existingStake.address;
            } else {
                reject('Stake account file and public key not found.');
                return;
            }
        }
        exec(`solana stake-account ${publicKey}`, async (error, stdout, stderr) => {
            if (stderr.includes("AccountNotFound")) {
                // Create the stake account
                await moveAndCreateStakeAccount();
                resolve(`Stake account created.`);
            } else if (stderr.includes("is not a stake account")) {
                await moveAndCreateStakeAccount();
                resolve(`Stake account moved and recreated.`);
            } else if (error) {
                reject(`Error checking stake account: ${stderr}`);
            } else {
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Stake account exists:\n${outputLines}`);
            }
        });
    });
}

async function checkVoteAccount() {
    return new Promise((resolve, reject) => {
        let publicKey;
        if (fs.existsSync(votePath)) {
            publicKey = votePath;
        } else {
            const existingWallets = readWallets();
            const existingVote = existingWallets.find(wallet => wallet.name === capitalizeFirstLetter("vote"));
            if (existingVote) {
                publicKey = existingVote.address;
            } else {
                reject('Vote account file and public key not found.');
                return;
            }
        }
        exec(`solana vote-account ${publicKey}`, async (error, stdout, stderr) => {
            if (stderr.includes("account does not exist")) {
                await moveAndCreateVoteAccount();
                resolve(`Vote account created.`);
            } else if (stderr.includes("is not a vote account")) {
                await moveAndCreateVoteAccount();
                resolve(`Vote account moved and recreated.`);
            } else if (error) {
                reject(`Error checking vote account: ${stderr}`);
            } else {
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Vote account exists:\n${outputLines}`);
            }
        });
    });
}

// Function to create wallets.json file, if new wallets were created.
function createWalletsJSON() {
    if (!newWalletsCreated) {
        console.log('No new wallets were created; wallets.json will not be updated.');
        return;
    }

    const wallets = [
        { name: capitalizeFirstLetter("id"), address: execSync(`solana-keygen pubkey ${withdrawerPath}`).toString().trim() },
        { name: capitalizeFirstLetter("identity"), address: execSync(`solana-keygen pubkey ${identityPath}`).toString().trim() },
        { name: capitalizeFirstLetter("stake"), address: execSync(`solana-keygen pubkey ${stakePath}`).toString().trim() },
        { name: capitalizeFirstLetter("vote"), address: execSync(`solana-keygen pubkey ${votePath}`).toString().trim() },
    ];

    writeWallets(wallets);
}

// Main function: sequentially checks/creates stake then vote
async function main() {
    updateWallets();

    try {
        await checkStakeAccount();
        await checkVoteAccount();
        // After all, update wallets.json if new wallets were created
        createWalletsJSON();
    } catch (err) {
        console.error(`Error: ${err}`);
    }
}

main();
