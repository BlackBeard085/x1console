const { exec, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const homeDir = process.env.HOME || process.env.HOMEPATH;
const stakePath = path.join(homeDir, '.config/solana/stake.json');
const votePath = path.join(homeDir, '.config/solana/vote.json');
const identityPath = path.join(homeDir, '.config/solana/identity.json');
const withdrawerPath = path.join(homeDir, '.config/solana/id.json');
const archivePath = path.join(homeDir, '.config/solana/archive');

// Paths for wallets.json
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

// Function to capitalize the first letter of a string
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

// Function to update a specific wallet entry in wallets.json
function updateWalletEntry(wallets, name, address) {
    const entryIndex = wallets.findIndex(wallet => wallet.name === name);
    if (entryIndex !== -1) {
        wallets[entryIndex].address = address;
    } else {
        wallets.push({ name, address });
    }
}

// Function to read existing wallets.json
function readWallets() {
    if (fs.existsSync(walletsFilePath)) {
        return JSON.parse(fs.readFileSync(walletsFilePath, 'utf8')) || [];
    }
    return [];
}

// Function to write the wallets.json
function writeWallets(wallets) {
    fs.writeFileSync(walletsFilePath, JSON.stringify(wallets, null, 2));
    fs.copyFileSync(walletsFilePath, path.join(tachyonDir, 'wallets.json'));
    console.log(`wallets.json public addresses updated and copied to: ${tachyonDir}`);
}

// Function to update wallets.json with public keys from existing files
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
                    continue; // Skip if wallet file does not exist but entry exists
                }
                continue; // If the file doesn't exist and no entry in wallets.json, just skip
            }

            const publicKey = execSync(`solana-keygen pubkey ${file}`).toString().trim();
            const walletName = capitalizeFirstLetter(path.basename(file, '.json'));

            const existingWallet = wallets.find(wallet => wallet.name === walletName);
            if (existingWallet) {
                if (existingWallet.address === publicKey) {
                    console.log(`Skipping ${walletName} as it already exists in wallets.json.`);
                    continue; // Skip if wallet exists and public key matches
                } else {
                    // Update the wallet address if it has changed
                    updateWalletEntry(wallets, walletName, publicKey);
                    console.log(`Updated ${walletName} address in wallets.json.`);
                }
            } else {
                // Add new wallet entry
                updateWalletEntry(wallets, walletName, publicKey);
                console.log(`Added new wallet entry for ${walletName} in wallets.json.`);
            }
        }

        // Write updated wallets.json only if there were changes
        writeWallets(wallets);
    } catch (error) {
        console.error(`Error updating wallets.json: ${error}`);
    }
}

// Function to move and create new stake account
function moveAndCreateStakeAccount() {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync(archivePath)) {
            fs.mkdirSync(archivePath);
        }

        // Create a timestamped filename for the archived stake file
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

                exec(`solana create-stake-account ${stakePath} 1`, (createError) => {
                    if (createError) {
                        reject(`Error creating stake account: ${createError}`);
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

// Function to move and create new vote account
function moveAndCreateVoteAccount() {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync(archivePath)) {
            fs.mkdirSync(archivePath);
        }

        // Create a timestamped filename for the archived vote file
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

// Function to check stake account
function checkStakeAccount() {
    return new Promise((resolve, reject) => {
        let publicKey;
        if (fs.existsSync(stakePath)) {
            publicKey = stakePath;
        } else {
            const existingWallets = readWallets();
            const existingStake = existingWallets.find(wallet => wallet.name === capitalizeFirstLetter("stake"));
            if (existingStake) {
                publicKey = existingStake.address; // Use the pubkey from wallets.json
            } else {
                reject('Stake account file and public key not found.');
                return;
            }
        }

        exec(`solana stake-account ${publicKey}`, (error, stdout, stderr) => {
            if (stderr.includes("AccountNotFound")) {
                exec(`solana create-stake-account ${stakePath} 1`, (createErr) => {
                    if (createErr) {
                        reject(`Error creating stake account: ${stderr}`);
                    } else {
                        //resolve('Stake account created and copied to tachyon.');
                    }
                });
            } else if (stderr.includes("is not a stake account")) {
                moveAndCreateStakeAccount()
                    .then(message => resolve(message))
                    .catch(err => reject(err));
            } else if (error) {
                reject(`Error checking stake account: ${stderr}`);
                return;
            } else {
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Stake account exists:\n${outputLines}`);
            }
        });
    });
}

// Function to check vote account
function checkVoteAccount() {
    return new Promise((resolve, reject) => {
        let publicKey;
        if (fs.existsSync(votePath)) {
            publicKey = votePath;
        } else {
            const existingWallets = readWallets();
            const existingVote = existingWallets.find(wallet => wallet.name === capitalizeFirstLetter("vote"));
            if (existingVote) {
                publicKey = existingVote.address; // Use the pubkey from wallets.json
            } else {
                reject('Vote account file and public key not found.');
                return;
            }
        }

        exec(`solana vote-account ${publicKey}`, (error, stdout, stderr) => {
            if (stderr.includes("account does not exist")) {
                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 5`, (createErr) => {
                    if (createErr) {
                        reject(`Error creating vote account: ${stderr}`);
                    } else {
                        //resolve('Vote account created and copied to tachyon.');
                    }
                });
            } else if (stderr.includes("is not a vote account")) {
                moveAndCreateVoteAccount()
                    .then(message => resolve(message))
                    .catch(err => reject(err));
            } else if (error) {
                reject(`Error checking vote account: ${stderr}`);
                return;
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

// Main function to execute the checks
async function main() {
    updateWallets(); // Update wallets.json with existing public keys

    try {
        const [stakeResult, voteResult] = await Promise.all([
            checkStakeAccount(),
            checkVoteAccount(),
        ]);
        console.log(stakeResult);
        console.log(voteResult);

        // Create wallets.json after checking accounts
        createWalletsJSON();
    } catch (error) {
        console.error(`Error occurred: ${error}`);
    }
}

// Execute the main function
main();
