const os = require('os');
const { exec } = require('child_process');

// Store metrics in arrays
let cpuUsage = [];
let ramUsage = [];
let ioUsage = []; // Now this will hold I/O utilization data from iostat
let diskUsage = []; // For single disk usage percentage
let loadAverage = [];
let hourlyNetworkStats = { sent: [], received: [] }; // To track last hour data
let swapUsage = [];
let uploadSpeeds = [];
let downloadSpeeds = [];

// Flag for speedtest connection
let speedtestFailed = false;
let vnstatDataAvailable = true; // Flag to indicate if vnstat data is available

// Function to get system metrics
function getSystemMetrics() {
    return new Promise((resolve) => {
        // Get CPU usage
        const cpuLoad = os.loadavg()[0] / os.cpus().length * 100; // as percentage
        cpuUsage.push(cpuLoad);

        // Get RAM usage
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const usedMem = totalMem - freeMem;
        const ramLoad = (usedMem / totalMem) * 100; // as percentage
        ramUsage.push(ramLoad);
        
        // Get Disk usage - single reading
        exec("df / | tail -1 | awk '{print $5}'", (err, stdout) => {
            if (err) {
                console.error(`Error executing df: ${err}`);
                resolve();
                return;
            }
            const diskLoad = parseInt(stdout.trim().replace('%', '')); // Disk usage percentage
            diskUsage.push(diskLoad); // Just push the current reading
            resolve();
        });

        // Get Load Average
        const loadAvg = os.loadavg(); // [1-min, 5-min, 15-min]
        loadAverage.push(loadAvg[0]); // Use only 1-min load average

        // Get Network Usage using vnstat -h
        exec("vnstat -h", (err, stdout) => {
            if (err) {
                vnstatDataAvailable = false; // Mark vnstat data as unavailable
                resolve();
                return;
            }

            const lines = stdout.trim().split('\n');
            const currentTime = new Date();
            const currentHour = currentTime.getHours();

            // Process only the current hour row
            lines.forEach((line) => {
                const parts = line.split('|');
                if (parts.length === 4) {
                    const hourData = parts[0].trim();

                    // Check if the hour matches the current hour
                    if (hourData.includes(currentHour.toString())) {
                        // Get the received and sent data from the current hour
                        const receivedData = parts[1].trim().split(' ')[0]; // rx data
                        const sentData = parts[2].trim().split(' ')[0]; // tx data

                        // Convert received and sent data to bytes (GiB to bytes)
                        const recvBytes = parseFloat(receivedData.replace('GiB', '').trim()) * (1024 ** 3); // Convert GiB to bytes
                        const sentBytes = parseFloat(sentData.replace('GiB', '').trim()) * (1024 ** 3); // Convert GiB to bytes

                        hourlyNetworkStats.sent.push([Date.now(), sentBytes]);
                        hourlyNetworkStats.received.push([Date.now(), recvBytes]);
                    }
                }
            });

            // If no data found, mark vnstat data as unavailable
            if (hourlyNetworkStats.sent.length === 0 || hourlyNetworkStats.received.length === 0) {
                vnstatDataAvailable = false; // Mark vnstat data as unavailable if no data found
            }

            resolve();
        });

        // Get Swap usage
        exec("swapon --show | awk 'NR==2{print $3, $4}'", (err, stdout) => {
            if (err) {
                console.error(`Error executing swap usage: ${err}`);
                resolve();
                return;
            }
            const swapInfo = stdout.trim().split(' ');
            const swapUsed = parseFloat(swapInfo[1]); // Used swap in MiB (already in MB)
            const swapTotal = parseFloat(swapInfo[0]) * 1024; // Total swap in MiB (convert GiB to MiB)
            if (swapTotal > 0) {
                const swapUsagePercent = (swapUsed / swapTotal) * 100; // Usage percentage
                swapUsage.push(swapUsagePercent);
            } else {
                swapUsage.push(0); // Default to 0% if no total swap is available
            }
            resolve();
        });
    });
}

// Function to run iostat and capture I/O utilization
async function getIOUtilization() {
    return new Promise((resolve) => {
        exec("iostat -x | awk '$1 ~ /nvme1n1/ {print $23}'", (error, stdout) => {
            if (error) {
                console.error(`Error executing iostat: ${error}`);
                resolve();
                return;
            }
            const ioUtilization = parseFloat(stdout.trim());
            if (!isNaN(ioUtilization) && ioUtilization >= 0) {
                ioUsage.push(ioUtilization); // Add I/O Utilization to the array
            }
            resolve();
        });
    });
}

// Function to run speed test using speedtest-cli
async function runSpeedTest() {
    return new Promise((resolve) => {
        exec("speedtest-cli --simple", (error, stdout, stderr) => {
            if (error) {
                speedtestFailed = true; // Set the failed flag
                resolve();
                return;
            }

            const lines = stdout.split('\n');
            const downloadLine = lines[1].match(/(\d+(\.\d+)?)\s+(.+)/);
            const uploadLine = lines[2].match(/(\d+(\.\d+)?)\s+(.+)/);
            const downloadSpeed = downloadLine ? parseFloat(downloadLine[1]) : 0;
            const uploadSpeed = uploadLine ? parseFloat(uploadLine[1]) : 0;

            downloadSpeeds.push(downloadSpeed); // Download speed in Mbps
            uploadSpeeds.push(uploadSpeed); // Upload speed in Mbps
            resolve();
        });
    });
}

// Function to format bytes to GB
function formatBytesToGB(bytes) {
    return (bytes / (1024 ** 3)).toFixed(2); // Converts bytes to gigabytes
}

// Function to calculate min, max, mean, and last value
function calculateMetrics(array) {
    if (!Array.isArray(array) || array.length === 0) {
        return { min: 0, max: 0, mean: 0, last: 0 }; // Return default values if the array is not valid or empty
    }

    // Filter out any undefined or non-numeric values
    const validValues = array.filter(value => typeof value === 'number' && !isNaN(value));

    if (validValues.length === 0) {
        return { min: 0, max: 0, mean: 0, last: 0 }; // If no valid numbers, return default values
    }
    
    const min = Math.min(...validValues).toFixed(2);
    const max = Math.max(...validValues).toFixed(2);
    const mean = (validValues.reduce((a, b) => a + b, 0) / validValues.length).toFixed(2);
    const last = validValues[validValues.length - 1].toFixed(2); // No need to check again

    return { min, max, mean, last };
}

// Main function to gather metrics and generate a report
async function generateReport(duration) {
    const endTime = Date.now() + duration * 1000; // End time in milliseconds

    // Collect metrics for the specified duration
    while (Date.now() < endTime) {
        await getSystemMetrics();
        await getIOUtilization(); // Get the I/O Utilization from iostat
        await runSpeedTest();
        await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for 1 second
    }

    // Calculate metrics for the last hour
    const sentBytesLastHour = hourlyNetworkStats.sent.map(([_, bytes]) => bytes);
    const receivedBytesLastHour = hourlyNetworkStats.received.map(([_, bytes]) => bytes);

    const cpuMetrics = calculateMetrics(cpuUsage);
    const ramMetrics = calculateMetrics(ramUsage);
    const ioMetrics = calculateMetrics(ioUsage); // Now includes I/O Utilization metrics
    const diskUsageCurrent = diskUsage[diskUsage.length - 1] || 0; // Get current disk usage
    const loadMetrics = calculateMetrics(loadAverage);
    const networkSentMetrics = calculateMetrics(sentBytesLastHour);
    const networkReceivedMetrics = calculateMetrics(receivedBytesLastHour);
    const swapMetrics = calculateMetrics(swapUsage);
    const downloadMetrics = calculateMetrics(downloadSpeeds);
    const uploadMetrics = calculateMetrics(uploadSpeeds);

    // Output report to console
    const report = `
    ---------------------
    Performance Report
    ---------------------
    
    CPU Usage (%):
      Min: ${cpuMetrics.min} %
      Max: ${cpuMetrics.max} %
      Mean: ${cpuMetrics.mean} %
      Last: ${cpuMetrics.last} %

    RAM Usage (%):
      Min: ${ramMetrics.min} %
      Max: ${ramMetrics.max} %
      Mean: ${ramMetrics.mean} %
      Last: ${ramMetrics.last} %

    I/O Utilization (%):
      Min: ${ioMetrics.min} %
      Max: ${ioMetrics.max} %
      Mean: ${ioMetrics.mean} %
      Last: ${ioMetrics.last} %

    Disk Usage (%):
      Current: ${diskUsageCurrent} %

    Load Average (1 min):
      Min: ${loadMetrics.min}
      Max: ${loadMetrics.max}
      Mean: ${loadMetrics.mean}
      Last: ${loadMetrics.last}

    Network Sent (GB):
      Min: ${formatBytesToGB(networkSentMetrics.min)} GB
      Max: ${formatBytesToGB(networkSentMetrics.max)} GB
      Mean: ${formatBytesToGB(networkSentMetrics.mean)} GB
      Last: ${formatBytesToGB(networkSentMetrics.last)} GB

    Network Received (GB):
      Min: ${formatBytesToGB(networkReceivedMetrics.min)} GB
      Max: ${formatBytesToGB(networkReceivedMetrics.max)} GB
      Mean: ${formatBytesToGB(networkReceivedMetrics.mean)} GB
      Last: ${formatBytesToGB(networkReceivedMetrics.last)} GB

    Swap Usage (%):
      Min: ${swapMetrics.min} %
      Max: ${swapMetrics.max} %
      Mean: ${swapMetrics.mean} %
      Last: ${swapMetrics.last} %

    Download Speed (Mbps):
      Min: ${downloadMetrics.min === null ? 'N/A' : downloadMetrics.min} Mbps
      Max: ${downloadMetrics.max === null ? 'N/A' : downloadMetrics.max} Mbps
      Mean: ${downloadMetrics.mean === null ? 'N/A' : downloadMetrics.mean} Mbps
      Last: ${downloadMetrics.last === null ? 'N/A' : downloadMetrics.last} Mbps

    Upload Speed (Mbps):
      Min: ${uploadMetrics.min === null ? 'N/A' : uploadMetrics.min} Mbps
      Max: ${uploadMetrics.max === null ? 'N/A' : uploadMetrics.max} Mbps
      Mean: ${uploadMetrics.mean === null ? 'N/A' : uploadMetrics.mean} Mbps
      Last: ${uploadMetrics.last === null ? 'N/A' : uploadMetrics.last} Mbps

    ---------------------
    ${speedtestFailed ? 'Speedtest could not connect to the speedtest CLI host.' : 'Speedtest executed successfully.'}
    
    ${vnstatDataAvailable ? '' : 'Not enough data available from vnstat to display network statistics for the last hour.'}
    ---------------------`;

    console.log(report);
    process.exit(0); // Exit the script
}

// Start monitoring for 60 seconds
generateReport(60);
