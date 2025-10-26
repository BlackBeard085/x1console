const { exec } = require('child_process');
const fs = require('fs').promises;
const util = require('util');
const execPromise = util.promisify(exec);
const HISTORY_FILE = 'balance_history.json';

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
                return '';
            }
        }
    }
}

async function getBalance(address) {
    const output = await runCommand(`solana balance ${address}`);
    const balance = output.trim().split(' ')[0];
    return parseFloat(balance);
}

async function getEpochInfo() {
    const output = await runCommand(`solana epoch-info`);
    const epochLine = output.split('\n').find(line => line.includes('Epoch:'));
    const epoch = epochLine ? epochLine.split(':')[1].trim() : '';
    const timeLine = output.split('\n').find(line => line.includes('Epoch Completed Time:'));
    const remainingTimeMatch = timeLine ? timeLine.match(/\(([^)]+)\)/) : null;
    const remainingTime = remainingTimeMatch ? remainingTimeMatch[1] : '';
    return { epoch, remainingTime };
}

async function getStakeAccounts() {
    const allstakesData = await fs.readFile('allstakes.json', 'utf8');
    const allstakes = JSON.parse(allstakesData);
    const stakeEntries = allstakes.filter(entry => /^Stake/.test(entry.name));
    return stakeEntries.map(entry => entry.address);
}

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

// Load previous epoch, balances, and reward info
async function loadPreviousState() {
    try {
        const data = await fs.readFile(HISTORY_FILE, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        // Defaults if file doesn't exist
        return {
            lastEpoch: null,
            voteBalance: 0,
            stakeBalance: 0,
            lastVoteReward: 0,
            lastStakeReward: 0
        };
    }
}

// Save current epoch, balances, and reward info
async function saveCurrentState(state) {
    await fs.writeFile(HISTORY_FILE, JSON.stringify(state, null, 2));
}

// Main function to check for epoch change and compute reward if changed
async function checkEpochAndUpdate() {
    const { epoch: currentEpoch } = await getEpochInfo();
    const prevState = await loadPreviousState();

    if (prevState.lastEpoch !== currentEpoch) {
        // Epoch has changed, compute rewards
        const walletsData = await fs.readFile('wallets.json', 'utf8');
        const wallets = JSON.parse(walletsData);
        const voteWallet = wallets.find(w => w.name === 'Vote');
        const voteAddress = voteWallet ? voteWallet.address : '';

        const currentVoteBalance = await getBalance(voteAddress);
        const currentVoteReward = currentVoteBalance;

        const stakeAddresses = await getStakeAccounts();
        let currentStakeBalance = 0;
        for (const addr of stakeAddresses) {
            currentStakeBalance += await getBalance(addr);
        }
        const currentStakeReward = currentStakeBalance;

        // Calculate reward as difference from previous rewards
        const voteRewardDiff = currentVoteReward - (prevState.lastVoteReward || 0);
        const stakeRewardDiff = currentStakeReward - (prevState.lastStakeReward || 0);

        // Save new state with current balances and rewards as last rewards
        await saveCurrentState({
            lastEpoch: currentEpoch,
            voteBalance: currentVoteBalance,
            stakeBalance: currentStakeBalance,
            lastVoteReward: currentVoteReward,
            lastStakeReward: currentStakeReward
        });

        // Return rewards as "New Rewards"
        return {
            epoch: currentEpoch,
            voteReward: voteRewardDiff,
            stakeReward: stakeRewardDiff,
            currentVoteBalance,
            currentStakeBalance,
            epochChanged: true
        };
    } else {
        // Same epoch, show last rewards
        const lastRewards = {
            voteReward: prevState.lastVoteReward,
            stakeReward: prevState.lastStakeReward
        };
        return {
            epoch: currentEpoch,
            voteReward: lastRewards.voteReward || 0,
            stakeReward: lastRewards.stakeReward || 0,
            currentVoteBalance: prevState.voteBalance,
            currentStakeBalance: prevState.stakeBalance,
            epochChanged: false
        };
    }
}

// Main execution
async function main() {
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

    // Check epoch change and get rewards
    const epochData = await checkEpochAndUpdate();

    // Prepare output line
    let line = `Total Stake: ${totalStake} | Delegated Stake: ${delegatedStake} | Self Stake: ${totalSelfDelegated}\n`;
    line += `Epoch: ${epochInfo.epoch} | Remaining Time: ${epochInfo.remainingTime}\n\n`;
    line += `Balances:\n`;
    line += `Id: ${idBalance}  |  Identity: ${identityBalance}  |  Vote: ${voteBalance}\n`;
    // Show total unstaked and rewards on same line
    if (epochData.epochChanged) {
        line += `Total Unstaked Balance: ${totalUnstaked} | Vote Reward: ${epochData.voteReward.toFixed(4)} (New Rewards) | Stake Reward: ${epochData.stakeReward.toFixed(4)} (New Rewards)\n`;
    } else {
        line += `Total Unstaked Balance: ${totalUnstaked} | Vote Reward: ${epochData.voteReward.toFixed(4)} (Last Rewards) | Stake Reward: ${epochData.stakeReward.toFixed(4)} (Last Rewards)\n`;
    }

    console.log(line);
}
main().catch(console.error);
