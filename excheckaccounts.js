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
    fs.mkdirSync(walletsDir, { recursive: true }); // Create the x1console directory if it doesn't exist
}

if (!fs.existsSync(tachyonDir)) {
    fs.mkdirSync(tachyonDir, { recursive: true }); // Create the tachyon directory if it doesn't exist
}

let newWalletsCreated = false; // Track if any new wallets are created

// Function to capitalize the first letter of a string
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

// Function to update wallets.json with public keys from existing files
function updateWallets() {
    const files = [withdrawerPath, identityPath, stakePath, votePath];
    const wallets = [];

    try {
        // Collect public keys from the specified files
        for (const file of files) {
            if (fs.existsSync(file)) {
                const publicKey = execSync(`solana-keygen pubkey ${file}`).toString().trim();
                const walletName = capitalizeFirstLetter(path.basename(file, '.json'));
                wallets.push({ name: walletName, address: publicKey });
            }
        }

        // Write the wallets to wallets.json
        fs.writeFileSync(walletsFilePath, JSON.stringify(wallets, null, 2));
        console.log('wallets.json created/updated.');

        // Copy the wallets.json to the tachyon directory
        fs.copyFileSync(walletsFilePath, path.join(tachyonDir, 'wallets.json'));
        console.log(`Copied wallets.json to: ${tachyonDir}`);
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
        const newStakePath = path.join(archivePath, 'stake.json');
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
                newWalletsCreated = true; // A new wallet was created for the stake account

                exec(`solana create-stake-account ${stakePath} 2`, (createError) => {
                    if (createError) {
                        reject(`Error creating stake account: ${createError}`);
                        return;
                    }

                    // Copy the newly generated stake.json to the tachyon directory
                    fs.copyFileSync(stakePath, path.join(tachyonDir, 'stake.json'));
                    console.log(`Copied stake.json to: ${tachyonDir}`);

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
        const newVotePath = path.join(archivePath, 'vote.json');
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
                newWalletsCreated = true; // A new wallet was created for the vote account

                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 10`, (createError) => {
                    if (createError) {
                        reject(`Error creating vote account: ${createError}`);
                        return;
                    }

                    // Copy the newly generated vote.json to the tachyon directory
                    fs.copyFileSync(votePath, path.join(tachyonDir, 'vote.json'));
                    console.log(`Copied vote.json to: ${tachyonDir}`);

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
        exec(`solana stake-account ${stakePath}`, (error, stdout, stderr) => {
            if (stderr.includes("AccountNotFound")) {
                exec(`solana create-stake-account ${stakePath} 2`, (createErr) => {
                    if (createErr) {
                        reject(`Error creating stake account: ${stderr}`);
                    } else {
                        // Copy the newly generated stake.json to the tachyon directory
                        fs.copyFileSync(stakePath, path.join(tachyonDir, 'stake.json'));
                        resolve('Stake account created and copied to tachyon.');
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
        exec(`solana vote-account ${votePath}`, (error, stdout, stderr) => {
            if (stderr.includes("account does not exist")) {
                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 10`, (createErr) => {
                    if (createErr) {
                        reject(`Error creating vote account: ${stderr}`);
                    } else {
                        // Copy the newly generated vote.json to the tachyon directory
                        fs.copyFileSync(votePath, path.join(tachyonDir, 'vote.json'));
                        resolve('Vote account created and copied to tachyon.');
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
        console.log('No new wallets were created; wallets.json will not be generated.');
        return;
    }

    const wallets = [
        { name: capitalizeFirstLetter("id"), address: execSync(`solana-keygen pubkey ${withdrawerPath}`).toString().trim() },
        { name: capitalizeFirstLetter("identity"), address: execSync(`solana-keygen pubkey ${identityPath}`).toString().trim() },
        { name: capitalizeFirstLetter("stake"), address: execSync(`solana-keygen pubkey ${stakePath}`).toString().trim() },
        { name: capitalizeFirstLetter("vote"), address: execSync(`solana-keygen pubkey ${votePath}`).toString().trim() },
    ];

    fs.writeFileSync(walletsFilePath, JSON.stringify(wallets, null, 2));
    console.log('wallets.json created/updated.');

    // Copy the wallets.json to the tachyon directory
    fs.copyFileSync(walletsFilePath, path.join(tachyonDir, 'wallets.json'));
    console.log(`Copied wallets.json to: ${tachyonDir}`);
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
