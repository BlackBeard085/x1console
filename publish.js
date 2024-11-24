const readline = require('readline');
const { exec } = require('child_process');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

// Function to ask a question and return a promise
function askQuestion(query) {
    return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
    try {
        // Get user inputs
        const name = await askQuestion('Validator Name: ');
        const url = await askQuestion('Web URL: ');
        const imageUrl = await askQuestion('Icon (image URL - jpg/png): ');

        // Validate image URL if not blank
        if (imageUrl && !imageUrl.match(/\.(jpeg|jpg|png)$/i)) {
            console.error('Invalid image URL. Please provide a URL ending with .jpg or .png.');
            rl.close();
            return;
        }

        // Construct command
        let command = `solana validator-info publish "${name}"`;
        if (url) {
            command += ` -w "${url}"`;
        }
        if (imageUrl) {
            command += ` -i "${imageUrl}"`;
        }
        command += ` -k $HOME/.config/solana/identity.json`;

        // Execute the command and handle output
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing command: ${error.message}`);
                return;
            }
            if (stderr) {
                console.error(`stderr: ${stderr}`);
                return;
            }
            console.log(`stdout: ${stdout}`);
        });
    } catch (err) {
        console.error('Error:', err);
    } finally {
        rl.close();
    }
}

// Run the main function
main();
