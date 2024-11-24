const { exec } = require('child_process');
const path = require('path');
const homeDir = process.env.HOME || process.env.HOMEPATH;
const stakePath = path.join(homeDir, '.config/solana/stake.json');
const votePath = path.join(homeDir, '.config/solana/vote.json');
const identityPath = path.join(homeDir, '.config/solana/identity.json');
const withdrawerPath = path.join(homeDir, '.config/solana/id.json');

function checkStakeAccount() {
    return new Promise((resolve, reject) => {
        exec(`solana stake-account ${stakePath}`, (error, stdout, stderr) => {
            // Checking if stderr indicates the account does not exist or is invalid
            if (stderr.includes("AccountNotFound")) {
                // Create stake account since it does not exist
                exec(`solana create-stake-account ${stakePath} 2`, (createErr, createStdout, createStderr) => {
                    if (createErr) {
                        reject(`Error creating stake account: ${createStderr}`);
                    } else {
                        resolve(`Stake account created: ${createStdout}`);
                    }
                });
            } else if (stderr.includes("is not a stake account")) {
                // Handle the case where the account type is incorrect
                resolve(`The stake account was funded before being registered; a fresh wallet is required to proceed.`);
            } else if (error) {
                // If there's an unexpected error (not account does not exist)
                reject(`Error checking stake account: ${stderr}`);
                return;
            } else {
                // The account exists
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Stake account exists:\n${outputLines}`);
            }
        });
    });
}

function checkVoteAccount() {
    return new Promise((resolve, reject) => {
        exec(`solana vote-account ${votePath}`, (error, stdout, stderr) => {
            // Checking if stderr indicates the account does not exist or is invalid
            if (stderr.includes("account does not exist")) {
                // Create vote account since it does not exist
                exec(`solana create-vote-account ${votePath} ${identityPath} ${withdrawerPath} --commission 10`, (createErr, createStdout, createStderr) => {
                    if (createErr) {
                        reject(`Error creating vote account: ${createStderr}`);
                    } else {
                        resolve(`Vote account created: ${createStdout}`);
                    }
                });
            } else if (stderr.includes("is not a vote account")) {
                // Handle the case where the account type is incorrect
                resolve(`The vote account was funded before being registered; a fresh wallet is required to proceed.`);
            } else if (error) {
                // If there's an unexpected error (not account does not exist)
                reject(`Error checking vote account: ${stderr}`);
                return;
            } else {
                // The account exists
                const outputLines = stdout.split('\n').slice(0, 10).join('\n');
                resolve(`Vote account exists:\n${outputLines}`);
            }
        });
    });
}

async function main() {
    try {
        const [stakeResult, voteResult] = await Promise.all([
            checkStakeAccount(),
            checkVoteAccount(),
        ]);
        console.log(stakeResult);
        console.log(voteResult);
    } catch (error) {
        console.error(`Error occurred: ${error}`);
    }
}

main();
