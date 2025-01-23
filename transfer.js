const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const addressBookPath = path.join(__dirname, 'addressbook.json');
const walletsPath = path.join(process.env.HOME, 'x1console', 'wallets.json');
const allStakesPath = path.join(process.env.HOME, 'x1console', 'allstakes.json');

// Function to prompt for user input
const promptUser = (question) => {
    return new Promise((resolve) => {
        process.stdout.write(question);
        process.stdin.once('data', (data) => {
            resolve(data.toString().trim());
        });
    });
};

// Function to load the address book
const loadAddressBook = () => {
    if (fs.existsSync(addressBookPath)) {
        const data = fs.readFileSync(addressBookPath);
        return JSON.parse(data);
    }
    return [];
};

// Function to save an entry in the address book
const saveAddressBook = (addressBook) => {
    fs.writeFileSync(addressBookPath, JSON.stringify(addressBook, null, 2));
};

// Function to load wallets and stakes from both wallets.json and allstakes.json and populate the address book without duplicates
const populateAddressBookFromFiles = () => {
    const existingAddressBook = loadAddressBook();
    const existingAddresses = new Set(existingAddressBook.map(entry => entry.address));

    // Load from wallets.json
    if (fs.existsSync(walletsPath)) {
        const walletsData = fs.readFileSync(walletsPath);
        const wallets = JSON.parse(walletsData);
        
        if (Array.isArray(wallets)) {
            wallets.forEach(wallet => {
                const newEntry = {
                    name: wallet.name || "Unknown",
                    address: wallet.address || "Unknown",
                };
                if (!existingAddresses.has(newEntry.address)) {
                    existingAddressBook.push(newEntry);
                    existingAddresses.add(newEntry.address);
                }
            });
            console.log(`Address book populated from ${walletsPath}.`);
        } else {
            console.log(`Invalid format in ${walletsPath}. Expected an array.`);
        }
    } else {
        console.log(`${walletsPath} does not exist.`);
    }

    // Load from allstakes.json
    if (fs.existsSync(allStakesPath)) {
        const stakesData = fs.readFileSync(allStakesPath);
        const stakes = JSON.parse(stakesData);
        
        if (Array.isArray(stakes)) {
            stakes.forEach(stake => {
                const newEntry = {
                    name: stake.name || "Unknown",
                    address: stake.address || "Unknown",
                };
                if (!existingAddresses.has(newEntry.address)) {
                    existingAddressBook.push(newEntry);
                    existingAddresses.add(newEntry.address);
                }
            });
            console.log(`Address book populated from ${allStakesPath}.`);
        } else {
            console.log(`Invalid format in ${allStakesPath}. Expected an array.`);
        }
    } else {
        console.log(`${allStakesPath} does not exist.`);
    }

    saveAddressBook(existingAddressBook);
};

// Function to show the address book in a table format
const showAddressBook = (addressBook) => {
    console.log("\nWho would you like to transfer to?");
    console.log("ID\tName                Address                          ");
    console.log("--------------------------------------------------------------");
    addressBook.forEach((entry, index) => {
        const nameColumn = entry.name.padEnd(20, ' '); 
        const addressColumn = entry.address.length > 30
            ? entry.address.substr(0, 27) + '...'
            : entry.address.padEnd(30, ' '); 
        console.log(`${index + 1}\t${nameColumn}${addressColumn}`);
    });
    console.log("--------------------------------------------------------------");
};

// Function to execute the transfer
const executeTransfer = (address, amount) => {
    const command = `solana transfer ${address} ${amount} --allow-unfunded-recipient`;
    console.log(`Executing: ${command}`);
    try {
        execSync(command, { stdio: 'inherit' });
        console.log('Transfer successful!');
    } catch (error) {
        console.error(`Failed to execute transfer: ${error.message}`);
    }
};

// Function to validate Solana address
const isValidSolanaAddress = (address) => {
    return address.length === 44; 
};

// Function to pause for user input
const pauseForUser = async () => {
    await promptUser('Press any key to continue...');
};

// Main function to handle user input and transfers
const main = async () => {
    populateAddressBookFromFiles();
    let continueTransfer = true;

    while (continueTransfer) {
        const addressBook = loadAddressBook();

        let transferOption;
        while (true) {
            transferOption = await promptUser(
                '\nChoose an option:\n1: Transfer to someone new\n2: Transfer from address book\n3: Exit\n\nPlease enter 1, 2, or 3 (or just press Enter to return to the menu): '
            );

            if (transferOption === '1' || transferOption === '2' || transferOption === '3') {
                break; // exit the loop if a valid option is chosen
            } else {
                console.log('Invalid option. Please choose either 1, 2, or 3.');
            }
        }

        if (transferOption === '1') {
            const newEntryName = await promptUser('Enter the name transferring to (or just press Enter to go back): ');
            if (!newEntryName) {
                console.log('Process cancelled, returning to menu.');
                await pauseForUser();
                continue;
            }

            let newEntryAddress;
            while (true) {
                newEntryAddress = await promptUser('Enter the address transferring to (or just press Enter to go back): ');
                if (!newEntryAddress) {
                    console.log('Process cancelled, returning to menu.');
                    await pauseForUser();
                    break;
                }
                if (isValidSolanaAddress(newEntryAddress)) {
                    break;
                } else {
                    console.log('The address entered is not a valid Solana address.');
                }
            }
            if (!newEntryAddress) continue;

            const transferAmount = await promptUser('Enter the amount to transfer (or just press Enter to go back): ');
            if (!transferAmount) {
                console.log('Process cancelled, returning to menu.');
                await pauseForUser();
                continue;
            }

            const confirmTransfer = await promptUser(
                `Confirm transfer of ${transferAmount} to ${newEntryName} (${newEntryAddress})? (yes/no): `
            );

            if (confirmTransfer.toLowerCase() === 'yes') {
                executeTransfer(newEntryAddress, transferAmount);
                
                const currentAddressBook = loadAddressBook();
                const namesSet = new Set(currentAddressBook.map(entry => entry.address));
                if (!namesSet.has(newEntryAddress)) {
                    currentAddressBook.push({ name: newEntryName, address: newEntryAddress });
                    saveAddressBook(currentAddressBook);
                    console.log(`Added ${newEntryName} to the address book.`);
                }
            } else {
                console.log('Transfer canceled.');
            }

        } else if (transferOption === '2') {
            if (addressBook.length === 0) {
                console.log("Address book is empty. Please add entries first.");
                await pauseForUser(); // Pause for user to read the message
                continueTransfer = false; // Terminating script if the address book is empty
                break;
            }

            showAddressBook(addressBook);
            const selectedEntryId = parseInt(await promptUser('Enter the ID to transfer to (or just press Enter to go back): ')) - 1;

            if (selectedEntryId < 0 || selectedEntryId >= addressBook.length) {
                console.log('Invalid selection. Please try again.');
                continue;
            }

            const transferAmount = await promptUser('Enter the amount to transfer (or just press Enter to go back): ');
            if (!transferAmount) {
                console.log('Process cancelled, returning to menu.');
                await pauseForUser();
                continue;
            }

            const confirmTransfer = await promptUser(
                `Confirm transfer of ${transferAmount} to ${addressBook[selectedEntryId].name} (${addressBook[selectedEntryId].address})? (yes/no): `
            );

            if (confirmTransfer.toLowerCase() === 'yes') {
                executeTransfer(addressBook[selectedEntryId].address, transferAmount);
            } else {
                console.log('Transfer canceled.');
            }

        } else if (transferOption === '3') {
            console.log('Exiting the script. Have a nice day!');
            process.stdin.pause();
            return; // Terminate the script
        }

        // Ask if user wants to make another transfer after valid operations
        const anotherTransfer = await promptUser('Would you like to make another transfer? (yes/no): ');
        continueTransfer = anotherTransfer.toLowerCase() === 'yes';
    }

    process.stdin.pause();
    console.log('Exiting transfers');
};

// Run the main function
main().catch(err => {
    console.error(`Error: ${err.message}`);
});
