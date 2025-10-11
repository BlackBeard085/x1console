const { exec } = require('child_process');
const fs = require('fs');

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
        // Extract the RPC URL
        const rpcUrl = rpcLine.split(': ')[1]; // Gets the URL after "RPC URL: "
        console.log(`RPC URL: ${rpcUrl}`);

        // Save the RPC URL into connectednetwork.json
        const data = { rpcUrl: rpcUrl };
        fs.writeFile('connectednetwork.json', JSON.stringify(data, null, 2), (err) => {
            if (err) {
                console.error(`Error writing to file: ${err.message}`);
            } else {
            //    console.log('RPC URL saved to connectednetwork.json');
            }
        });
    } else {
        console.log('RPC URL not found in output.');
    }
});
