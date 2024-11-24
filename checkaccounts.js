const { exec } = require('child_process');
const path = require('path');

const homeDir = process.env.HOME || process.env.HOMEPATH;
const stakePath = path.join(homeDir, '.config/solana/stake.json');
const votePath = path.join(homeDir, '.config/solana/vote.json');
const identityPath = path.join(homeDir, '.config/solana/identity.json'); // Adjust as needed
const withdrawerPath = path.join(homeDir, '.config/solana/id.json'); // Adjust as needed

function checkStakeAccount() {
    return new Promise((resolve, reject) => {
        exec(`solana stake-account ${stakePath}`, (error, stdout, stderr) => {
            if (error) {
                reject(`Error checking stake account: ${stderr}`);
                return;
            }
            if (stdout.includes("is not a stake account")) {
                // Create stake account since it does not exist
                exec(`solana create-stake-account ${stakePath} 2`, (createErr, createStdout, createStderr) => {
                    if (createErr) {
                        reject(`Error creating stake account: ${createStderr}`);
                    } else {
                        resolve(`Stake account created: ${createStdout}`);
                    }
                });
            } else {
                // Limit output to 10 lines
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Stake account exists:\n${outputLines}`);
            }
        });
    });
}

function checkVoteAccount() {
    return new Promise((resolve, reject) => {
        exec(`solana vote-account ${votePath}`, (error, stdout, stderr) => {
            if (error) {
                reject(`Error checking vote account: ${stderr}`);
                return;
            }
            if (stdout.includes("is not a vote account")) {
                // Create vote account since it does not exist
                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 10`, (createErr, createStdout, createStderr) => {
                    if (createErr) {
                        reject(`Error creating vote account: ${createStderr}`);
                    } else {
                        resolve(`Vote account created: ${createStdout}`);
                    }
                });
            } else {
                // Limit output to 10 lines
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Vote account exists:\n${outputLines}`);
            }
        });
    });
}

async function main() {
    try {
        console.log(await checkStakeAccount());
        console.log(await checkVoteAccount());
    } catch (error) {
        console.error(error);
    }
}

main();
