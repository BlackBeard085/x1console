const { exec } = require('child_process');
const fs = require('fs').promises;
const util = require('util');

const execPromise = util.promisify(exec);

async function runCommand(cmd, retries = 3, delayMs = 1000) {
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            const { stdout } = await execPromise(cmd);
            return stdout;
        } catch (err) {
            console.error(`Attempt ${attempt} failed for command: ${cmd}`);
            if (attempt < retries) {
                await new Promise(res => setTimeout(res, delayMs));
            } else {
                console.error(`All retries failed for command: ${cmd}`);
                return ''; // or throw error if desired
            }
        }
    }
}

// Fetch the balance of an address
async function getBalance(address) {
    const output = await runCommand(`solana balance ${address}`);
    const balance = output.trim().split(' ')[0]; // first token is balance
    return balance;
}

// Fetch epoch info
async function getEpochInfo() {
    const output = await runCommand(`solana epoch-info`);
    const epochLine = output.split('\n').find(line => line.includes('Epoch:'));
    const epoch = epochLine ? epochLine.split(':')[1].trim() : '';

    const timeLine = output.split('\n').find(line => line.includes('Epoch Completed Time:'));
    const remainingTimeMatch = timeLine ? timeLine.match(/\(([^)]+)\)/) : null;
    const remainingTime = remainingTimeMatch ? remainingTimeMatch[1] : '';

    return { epoch, remainingTime };
}

// Get all stake account addresses where name starts with 'Stake'
async function getStakeAccounts() {
    const allstakesData = await fs.readFile('allstakes.json', 'utf8');
    const allstakes = JSON.parse(allstakesData);
    const stakeEntries = allstakes.filter(entry => /^Stake/.test(entry.name));
    return stakeEntries.map(entry => entry.address);
}

// Get total active stake for a vote address
async function getTotalStake(voteAddress) {
    const output = await runCommand(`solana stakes ${voteAddress}`);
    const lines = output.split('\n');
    let total = 0;
    lines.forEach(line => {
        if (line.includes('Active Stake:')) {
            const parts = line.trim().split(/\s+/);
            const amountStr = parts[2];
            total += parseFloat(amountStr);
        }
    });
    return total.toFixed(2);
}

// Get total self delegated stake
async function getTotalSelfDelegated() {
    const addresses = await getStakeAccounts();
    let totalSelf = 0;
    for (const addr of addresses) {
        const output = await runCommand(`solana stake-account ${addr}`);
        const match = output.match(/Active Stake:\s+([\d.]+)/);
        if (match) {
            totalSelf += parseFloat(match[1]);
        }
    }
    return totalSelf.toFixed(2);
}

// Get total unstaked balance
async function getTotalUnstakedBalance() {
    const addresses = await getStakeAccounts();
    let totalBalance = 0;
    for (const addr of addresses) {
        const output = await runCommand(`solana stake-account ${addr}`);
        const match = output.match(/Balance:\s+([\d.]+)/);
        if (match) {
            totalBalance += parseFloat(match[1]);
        }
    }
    const totalSelf = parseFloat(await getTotalSelfDelegated());
    const unstaked = totalBalance - totalSelf;
    return unstaked.toFixed(2);
}

async function main() {
    // Read wallets.json
    const walletsData = await fs.readFile('wallets.json', 'utf8');
    const wallets = JSON.parse(walletsData);

    const idWallet = wallets.find(w => w.name === 'Id');
    const identityWallet = wallets.find(w => w.name === 'Identity');
    const voteWallet = wallets.find(w => w.name === 'Vote');

    const idAddress = idWallet ? idWallet.address : '';
    const identityAddress = identityWallet ? identityWallet.address : '';
    const voteAddress = voteWallet ? voteWallet.address : '';

    const [idBalance, identityBalance, voteBalance, epochInfo, totalStake, totalSelfDelegated, totalUnstaked] = await Promise.all([
        getBalance(idAddress),
        getBalance(identityAddress),
        getBalance(voteAddress),
        getEpochInfo(),
        getTotalStake(voteAddress),
        getTotalSelfDelegated(),
        getTotalUnstakedBalance()
    ]);

    const delegatedStake = (parseFloat(totalStake) - parseFloat(totalSelfDelegated)).toFixed(2);

    // Output
    console.log(`Total Stake: ${totalStake} | Delegated Stake: ${delegatedStake} | Self Stake: ${totalSelfDelegated}`);
    console.log(`Epoch: ${epochInfo.epoch} | Remaining Time: ${epochInfo.remainingTime}`);
    console.log('');
    console.log('Balances:');
    console.log(`Id: ${idBalance}  |  Identity: ${identityBalance}  |  Vote: ${voteBalance}`);
    console.log(`Total Unstaked Balance: ${totalUnstaked}`);
}

main().catch(console.error);
