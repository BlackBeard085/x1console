const https = require('https');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process'); // Import exec to run shell commands

// Change this URL to your specific cluster API URL
const CLUSTER_URL = 'https://rpc.testnet.x1.xyz';

// Check if wallets.json exists
const walletsFilePath = path.join(__dirname, 'wallets.json');
let wallets;

try {
    wallets = JSON.parse(fs.readFileSync(walletsFilePath, 'utf8'));
} catch (error) {
    console.error('Performance metrics will show when wallets data is available');
    process.exit(1);
}

// Find the Identity wallet address
const identityWallet = wallets.find(wallet => wallet.name === "Identity");
const identityAddress = identityWallet ? identityWallet.address : undefined;

if (!identityAddress) {
    console.error('Identity wallet address not found!');
    process.exit(1);
}

// Function to print the header before data collection
function printPerformanceMetricsHeader() {
    console.log(`Performance metrics for Identity: ${identityAddress}`);
}

// Function to fetch the validator version using the shell command
function fetchValidatorVersion(identity) {
    return new Promise((resolve, reject) => {
        exec(`solana validators | grep ${identity}`, (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing command: ${stderr}`);
                return;
            }
            const versionInfo = stdout.match(/\d+\.\d+\.\d+/);
            if (versionInfo) {
                resolve(`v${versionInfo[0]}   `);
            } else {
                resolve('N/A');
            }
        });
    });
}

// Function to execute ./latency.sh and get its output
function fetchLatencyScriptOutput() {
    return new Promise((resolve, reject) => {
        exec('./latency.sh', (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing ./latency.sh: ${stderr}`);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

// Function to execute ./epoch_remaining.sh and get its output
function fetchEpochRemaining() {
    return new Promise((resolve, reject) => {
        exec('./epoch_remaining.sh', (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing ./epoch_remaining.sh: ${stderr}`);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

// Function to execute ./stakepercentage.sh and get its output
function fetchStakePercentage() {
    return new Promise((resolve, reject) => {
        exec('./stakepercentage.sh', (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing ./stakepercentage.sh: ${stderr}`);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

// Function to execute ./votesuccess.sh and get its output
function fetchVoteSuccess() {
    return new Promise((resolve, reject) => {
        exec('./votesuccess.sh', (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing ./votesuccess.sh: ${stderr}`);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

// Function to execute ./avgvotesuccess.sh and get its output
function fetchAvgVoteSuccess() {
    return new Promise((resolve, reject) => {
        exec('./avgvotesuccess.sh', (error, stdout, stderr) => {
            if (error) {
                reject(`Error executing ./avgvotesuccess.sh: ${stderr}`);
                return;
            }
            resolve(stdout.trim());
        });
    });
}

function fetchCurrentEpoch() {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'getEpochInfo'
        });
        const options = {
            hostname: CLUSTER_URL.replace(/^https?:\/\//, ''),
            port: 443,
            path: '/',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data)
            }
        };
        const req = https.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => { responseData += chunk; });
            res.on('end', () => {
                try {
                    const jsonResponse = JSON.parse(responseData);
                    resolve(jsonResponse.result);
                } catch (error) {
                    resolve(null);
                }
            });
        });
        req.on('error', () => { resolve(null); });
        req.write(data);
        req.end();
    });
}

function fetchBlockProduction(walletAddress, firstSlot, lastSlot) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'getBlockProduction',
            params: [{
                identity: walletAddress,
                range: { firstSlot, lastSlot },
                commitment: "confirmed"
            }]
        });
        const options = {
            hostname: CLUSTER_URL.replace(/^https?:\/\//, ''),
            port: 443,
            path: '/',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data)
            }
        };
        const req = https.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => { responseData += chunk; });
            res.on('end', () => {
                try {
                    const jsonResponse = JSON.parse(responseData);
                    resolve(jsonResponse.result || null);
                } catch (error) {
                    resolve(null);
                }
            });
        });
        req.on('error', () => { resolve(null); });
        req.write(data);
        req.end();
    });
}

async function fetchBlockProductionForLastEpochs() {
    try {
        // Fetch current epoch info and related data in parallel
        const currentEpochInfoPromise = fetchCurrentEpoch();
        const [
            epochRemainingOutput,
            totalStakePercent,
            voteSuccessOutput,
            avgVoteSuccessOutput
        ] = await Promise.all([
            fetchEpochRemaining(),
            fetchStakePercentage(),
            fetchVoteSuccess(),
            fetchAvgVoteSuccess()
        ]);

        const currentEpochInfo = await currentEpochInfoPromise;
        if (!currentEpochInfo) {
            console.log('Limited/No data to show.');
            return;
        }

        const currentEpoch = currentEpochInfo.epoch;
        const currentSlot = currentEpochInfo.absoluteSlot;
        const slotIndex = currentEpochInfo.slotIndex;

        const blockProductions = [];

        // Fetch block production data for current epoch
        const firstSlotCurrentEpoch = currentSlot - slotIndex;
        const lastSlotCurrentEpoch = currentSlot - 1;
        const currentEpochProductionPromise = fetchBlockProduction(
            identityAddress,
            firstSlotCurrentEpoch,
            lastSlotCurrentEpoch
        );

        // Calculate previous epoch range
        const lastSlotOfCurrentEpoch = currentSlot - 1;
        const firstSlotOfPreviousEpoch = lastSlotOfCurrentEpoch - 2500 + 1;
        const lastSlotOfPreviousEpoch = lastSlotOfCurrentEpoch - 1;
        const prevEpochProductionPromise = fetchBlockProduction(
            identityAddress,
            firstSlotOfPreviousEpoch,
            lastSlotOfPreviousEpoch
        );

        // Run both block production fetches in parallel
        const [currentEpochProduction, prevEpochProduction] = await Promise.all([
            currentEpochProductionPromise,
            prevEpochProductionPromise
        ]);

        if (currentEpochProduction) {
            blockProductions.push({ epoch: "Current Epoch", data: currentEpochProduction });
        }
        if (prevEpochProduction) {
            blockProductions.push({ epoch: `Previous 5 Epochs`, data: prevEpochProduction });
        }

        // Fetch validator version and latency in parallel
        const [validatorVersion, latencyOutput] = await Promise.all([
            fetchValidatorVersion(identityAddress),
            fetchLatencyScriptOutput().catch(() => 'Error fetching latency script')
        ]);

        // Log header info
        process.stdout.write(`${validatorVersion} ${latencyOutput}\n`);

        // Prepare table rows
        const rows = [];
        let showStakeInFirstRow = true;
        for (const [index, entry] of blockProductions.entries()) {
            const { epoch, data } = entry;
            if (data && data.value && data.value.byIdentity) {
                const identity = identityAddress;
                const prodData = data.value.byIdentity[identity];

                let assignedSlots = 0, blocksProduced = 0;
                if (prodData && Array.isArray(prodData)) {
                    assignedSlots = prodData[0] || 0;
                    blocksProduced = prodData[1] || 0;
                }
                const skippedSlots = assignedSlots - blocksProduced;
                const skippedPercent = assignedSlots > 0 ? ((skippedSlots / assignedSlots) * 100).toFixed(2) + '%' : '0.00%';
                const skippedDisplay = `${skippedSlots}/${assignedSlots} (${skippedPercent})`;

                const voteSuccess = index === 0 ? voteSuccessOutput : index === 1 ? avgVoteSuccessOutput : '';
                const totalStake = showStakeInFirstRow ? totalStakePercent : '';
                if (showStakeInFirstRow) showStakeInFirstRow = false;

                rows.push({
                    epoch: epoch === "Current Epoch" ? `Current ${currentEpoch}` : epoch,
                    skipped: skippedDisplay,
                    voteSuccess,
                    totalStake
                });
            } else {
                const totalStake = showStakeInFirstRow ? totalStakePercent : '';
                if (showStakeInFirstRow) showStakeInFirstRow = false;
                rows.push({
                    epoch: entry.epoch,
                    skipped: '0 / 0 (0.00%)',
                    voteSuccess: '',
                    totalStake
                });
            }
        }

        if (rows.length === 0) {
            console.log('Limited/No data to show.');
            return;
        }

        console.log(`\n| Epoch  ${epochRemainingOutput} | Skipped Slots   | Vote Success | Total Stake (%)      |`);
        console.log('|----------------------|-----------------|--------------|----------------------|');
        rows.forEach(row => {
            console.log(`| ${row.epoch.toString().padEnd(20)} | ${row.skipped.padEnd(15)} | ${row.voteSuccess.toString().padEnd(12)} | ${row.totalStake.toString().padEnd(20)} |`);
        });
    } catch {
        console.log('Limited/No data to show.');
    }
}

// *** Call the header once before starting data fetch ***
printPerformanceMetricsHeader();
fetchBlockProductionForLastEpochs();
