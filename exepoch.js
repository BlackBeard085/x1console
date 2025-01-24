const https = require('https');
const fs = require('fs');

// Change this URL to your specific cluster API URL
const CLUSTER_URL = 'https://rpc.testnet.x1.xyz';

// Load wallets from wallets.json
const wallets = JSON.parse(fs.readFileSync('wallets.json', 'utf8'));

// Find the Identity wallet address
const identityWallet = wallets.find(wallet => wallet.name === "Identity");
const identityAddress = identityWallet ? identityWallet.address : undefined;

if (!identityAddress) {
    console.error('Identity wallet address not found!');
    process.exit(1);
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

            res.on('data', (chunk) => {
                responseData += chunk;
            });

            res.on('end', () => {
                try {
                    const jsonResponse = JSON.parse(responseData);
                    resolve(jsonResponse.result);
                } catch (error) {
                    console.error('Error parsing current epoch response:', error.message);
                    resolve(null);
                }
            });
        });

        req.on('error', (error) => {
            console.error('Error fetching current epoch:', error.message);
            reject(error);
        });

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
                commitment: "confirmed" // Optional parameter for commitment
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

            res.on('data', (chunk) => {
                responseData += chunk;
            });

            res.on('end', () => {
                try {
                    const jsonResponse = JSON.parse(responseData);
                    resolve(jsonResponse.result || null);
                } catch (error) {
                    console.error('Error parsing block production response:', error.message);
                    resolve(null);
                }
            });
        });

        req.on('error', (error) => {
            console.error('Error fetching block production:', error.message);
            reject(error);
        });

        req.write(data);
        req.end();
    });
}

// Function to introduce a delay
async function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchBlockProductionForLastEpochs() {
    try {
        const currentEpochInfo = await fetchCurrentEpoch();
        if (!currentEpochInfo) {
            console.error("Could not retrieve current epoch info.");
            return;
        }

        const currentEpoch = currentEpochInfo.epoch;
        const currentSlot = currentEpochInfo.absoluteSlot; // Get the current absolute slot
        const slotIndex = currentEpochInfo.slotIndex; // Get the current slot index

        const blockProductions = [];

        // Fetch block production data for the current epoch
        const firstSlotCurrentEpoch = currentSlot - slotIndex; // First slot of the current epoch
        const lastSlotCurrentEpoch = currentSlot - 1; // Last slot of the current epoch

        const currentEpochProduction = await fetchBlockProduction(identityAddress, firstSlotCurrentEpoch, lastSlotCurrentEpoch);
        blockProductions.push({ epoch: "Current Epoch", data: currentEpochProduction }); // Save data for current epoch

        // Calculate first and last slots for previous epochs
        const lastSlotOfCurrentEpoch = currentSlot - 1; // Last slot of current epoch
        const firstSlotOfPreviousEpoch = lastSlotOfCurrentEpoch - 2500 + 1; // First slot of the range for previous epochs
        const lastSlotOfPreviousEpoch = lastSlotOfCurrentEpoch - 1; // Last slot of the previous epoch

        // Fetch block production data for the previous 5 epochs from 2500 slots back
        const blockProduction = await fetchBlockProduction(identityAddress, firstSlotOfPreviousEpoch, lastSlotOfPreviousEpoch);
        blockProductions.push({ epoch: `Previous 5 Epochs`, data: blockProduction }); // Save data for previous epochs

        // Log block production data for the last epochs
        console.log(`Performance metrics for Identity: ${identityAddress}`);
        
        // Extract apiVersion from the currentEpochProduction 
        const apiVersion = currentEpochProduction?.context?.apiVersion ? `v${currentEpochProduction.context.apiVersion}` : 'N/A';
        console.log(apiVersion);

        // Prepare data for table formatting
        const tableRows = [];

        for (const entry of blockProductions) {
            const { epoch, data } = entry;

            if (data && data.value && data.value.byIdentity) {
                const identity = identityAddress;

                // Unpack 'byIdentity' data
                const productionData = data.value.byIdentity[identity];

                let assignedLeaderSlots = 0;
                let blocksProduced = 0;
                let skippedSlots = 0;
                let skippedPercentage = '0.00%';

                if (productionData && Array.isArray(productionData)) {
                    assignedLeaderSlots = productionData[0] || 0; // First value
                    blocksProduced = productionData[1] || 0;      // Second value
                    skippedSlots = assignedLeaderSlots - blocksProduced;
                    skippedPercentage = assignedLeaderSlots > 0 ? ((skippedSlots / assignedLeaderSlots) * 100).toFixed(2) + '%' : '0.00%';
                }

                // Push the results into the table format
                tableRows.push({
                    epoch: epoch === "Current Epoch" ? `Current ${currentEpoch}` : epoch,
                    assigned: assignedLeaderSlots,
                    skipped: skippedSlots,
                    percentage: skippedPercentage
                });
            } else {
                tableRows.push({
                    epoch: entry.epoch,
                    assigned: 0,
                    skipped: 0,
                    percentage: '0.00%'
                });
            }
        }

        // Print the table
        console.log('\n| Epoch                | Assigned Slots | Skipped Slots | Percentage Skipped |');
        console.log('|----------------------|----------------|---------------|--------------------|');
        tableRows.forEach(row => {
            console.log(`| ${row.epoch.toString().padEnd(20)} | ${row.assigned.toString().padEnd(14)} | ${row.skipped.toString().padEnd(13)} | ${row.percentage.toString().padEnd(18)} |`);
        });
    } catch (error) {
        console.error('Error fetching epochs:', error.message);
    }
}

// Execute the function
fetchBlockProductionForLastEpochs();
