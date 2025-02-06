const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { exec } = require('child_process'); // Importing exec from child_process

// Path to the withdrawer config
const configFilePath = path.join(__dirname, 'withdrawerconfig.json');

// Function to update the keypair path in config file
const updateKeypairPath = (newKeypairPath) => {
    const config = { keypairPath: newKeypairPath };
    fs.writeFileSync(configFilePath, JSON.stringify(config, null, 4), 'utf-8');
    console.log('Keypair path updated successfully!');

    // Execute setwithdrawer.js after updating the config
    exec('node setwithdrawer.js', (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing setwithdrawer.js: ${error.message}`);
            return;
        }
        if (stderr) {
            console.error(`stderr: ${stderr}`);
            return;
        }
        console.log(`${stdout}`);
    });
};

// Function to prompt user for input
const promptUserForKeypairPath = () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    rl.question('Please type in the keypath to your withdrawer: ', (answer) => {
        updateKeypairPath(answer.trim());
        rl.close();
    });
};

// Run the prompt
promptUserForKeypairPath();
