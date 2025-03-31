const { exec } = require('child_process');

exec('solana config get', (error, stdout, stderr) => {
    if (error) {
        console.error(`Error executing command: ${error.message}`);
        return;
    }
    if (stderr) {
        console.error(`Error: ${stderr}`);
        return;
    }

    // Split the output into lines
    const outputLines = stdout.split('\n');

    // Find the line that contains "RPC URL:"
    const rpcLine = outputLines.find(line => line.includes('RPC URL:'));

    if (rpcLine) {
        // Extract and print the RPC URL
        const rpcUrl = rpcLine.split(': ')[1]; // Gets the URL after "RPC URL: "
        console.log(`RPC URL: ${rpcUrl}`);
    } else {
        console.log('RPC URL not found in output.');
    }
});
