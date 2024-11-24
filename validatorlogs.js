const { spawn } = require('child_process');
const { stdin, stdout } = process;
const path = require('path');

// Define the directory and the log file
const logDirectory = path.join(process.env.HOME, 'x1');
const logFile = 'log.txt';

// Change the current working directory to the log directory
process.chdir(logDirectory);

// Spawn the tail process
const tail = spawn('tail', ['-f', logFile]);

// Display output from the tail command
tail.stdout.on('data', (data) => {
    stdout.write(data); // Write log output to stdout
});

// Handle errors from the tail process
tail.stderr.on('data', (data) => {
    console.error(`Error: ${data}`);
});

// Exit the tail process if it exits for some reason
tail.on('exit', (code) => {
    console.log(`Tail process exited with code ${code}`);
});

// Listen for Ctrl+C or any key press to exit
stdin.setRawMode(true); // Enable raw mode to capture key events
stdin.resume(); // Start reading from stdin
stdin.on('data', (key) => {
    // Exit if any key is pressed
    console.log('Exiting log viewer...');
    tail.kill(); // Kill the tail process
    process.exit(); // Exit the script
});
