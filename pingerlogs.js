const { exec } = require('child_process');
const path = require('path');
const readline = require('readline');

// Get the user's HOME directory
const homeDir = process.env.HOME;

// Define the directory where the logs are located
const logDir = path.join(homeDir, 'pinger');

// Change to the log directory and run the tail command
process.chdir(logDir);

// Start the 'tail -f' process
const tail = exec('tail -f ping_output.txt');

// Set up readline to listen for keypress events
console.log('Listening to ping_output.txt logs. Press any key to exit...');

// Create an interface for reading from stdin
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: true
});

// Event handler for when data is received from the tail command
tail.stdout.on('data', (data) => {
  process.stdout.write(data);
});

// Event handler for when there's an error with the tail command
tail.stderr.on('data', (data) => {
  console.error(`Error: ${data}`);
});

// Event handler for when the tail command exits
tail.on('exit', (code) => {
  console.log(`Tail process exited with code ${code}`);
  rl.close();
});

// Listen for keypress to terminate the script
rl.on('line', () => {
  console.log('Exiting logs...');
  tail.kill(); // Kill the tail process
  process.exit(0); // Exit the script
});

// Handle SIGINT (e.g., Ctrl+C)
process.on('SIGINT', () => {
  console.log('Exiting logs...');
  tail.kill(); // Kill the tail process
  process.exit(0); // Exit the script
});
