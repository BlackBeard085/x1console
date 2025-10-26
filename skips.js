const https = require('https');
const fs = require('fs');
const path = require('path');

// --- Load connected network configuration ---
const networkConfigPath = path.join(__dirname, 'connectednetwork.json');
let rpcUrl;

try {
    const networkConfig = JSON.parse(fs.readFileSync(networkConfigPath, 'utf8'));
    rpcUrl = networkConfig.rpcUrl.trim();
    if (!rpcUrl) {
        console.error('RPC URL is missing in connectednetwork.json');
        process.exit(1);
    }
} catch (error) {
    console.error('Error reading connectednetwork.json:', error.message);
    process.exit(1);
}

// --- Load wallets.json ---
const walletsFilePath = path.join(__dirname, 'wallets.json');
let wallets;

try {
    wallets = JSON.parse(fs.readFileSync(walletsFilePath, 'utf8'));
} catch (error) {
    console.log('Performance metrics will show when wallets data is available');
    process.exit(1);
}

// Find the Identity wallet address
const identityWallet = wallets.find(wallet => wallet.name === "Identity");
const identityAddress = identityWallet ? identityWallet.address : undefined;

if (!identityAddress) {
    console.error('Identity wallet address not found!');
    process.exit(1);
}

// Function to fetch current epoch info
function fetchCurrentEpoch() {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            jsonrpc: '2.0',
            id: 1,
            method: 'getEpochInfo'
        });
        const hostname = rpcUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
        const options = {
            hostname: hostname,
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

// Function to fetch block production data for a slot range
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
        const hostname = rpcUrl.replace(/^https?:\/\//, '').replace(/\/$/, '');
        const options = {
            hostname: hostname,
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

// Main function to get current epoch skip rate
async function getCurrentEpochSkipRate() {
    const epochInfo = await fetchCurrentEpoch();
    if (!epochInfo) {
        console.log('Failed to fetch epoch info.');
        return;
    }

    const currentSlot = epochInfo.absoluteSlot || 0;
    const slotIndex = epochInfo.slotIndex || 0;
    const currentEpoch = epochInfo.epoch || 'N/A';

    // Calculate first and last slot of current epoch
    const firstSlot = currentSlot - slotIndex;
    const lastSlot = currentSlot - 1;

    // Fetch block production data for current epoch
    const blockProduction = await fetchBlockProduction(
        identityAddress,
        firstSlot,
        lastSlot
    );

    if (!blockProduction || !blockProduction.value || !blockProduction.value.byIdentity) {
        console.log('No block production data available.');
        return;
    }

    const prodData = blockProduction.value.byIdentity[identityAddress];

    let assignedSlots = 0;
    let blocksProduced = 0;

    if (prodData && Array.isArray(prodData)) {
        assignedSlots = prodData[0] || 0;
        blocksProduced = prodData[1] || 0;
    }

    const skippedSlots = assignedSlots - blocksProduced;
    const skipRate = assignedSlots > 0 ? (skippedSlots / assignedSlots) * 100 : 0;

    // Output in desired format: skipped slots / assigned slots then skip rate percentage
    console.log(`${skippedSlots}/${assignedSlots} (${skipRate.toFixed(2)}%)`);
}

// Run the function
getCurrentEpochSkipRate();
