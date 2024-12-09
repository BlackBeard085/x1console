const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const addressBookPath = path.join(__dirname, 'addressbook.json');
const walletsPath = path.join(process.env.HOME, 'x1console', 'wallets.json');

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
    fs.writeFileSync(addressBookPath, JSON.stringify(addressBook, null, 2)); // Pretty print format
};

// Function to load wallets from wallets.json and populate the address book without duplicates
const populateAddressBookFromWallets = () => {
    const existingAddressBook = loadAddressBook();
    const existingAddresses = new Set(existingAddressBook.map(entry => entry.address));

    if (fs.existsSync(walletsPath)) {
        const walletsData = fs.readFileSync(walletsPath);
        const wallets = JSON.parse(walletsData);
        
        if (Array.isArray(wallets)) {
            wallets.forEach(wallet => {
                const newEntry = {
                    name: wallet.name || "Unknown", // Fallback if name is missing
                    address: wallet.address || "Unknown", // Fallback if address is missing
                };
                if (!existingAddresses.has(newEntry.address)) {
                    existingAddressBook.push(newEntry);
                    existingAddresses.add(newEntry.address); // Add to Set
                }
            });
            saveAddressBook(existingAddressBook);
            console.log(`Address book populated from ${walletsPath}.`);
        } else {
            console.log(`Invalid format in ${walletsPath}. Expected an array.`);
        }
    } else {
        console.log(`${walletsPath} does not exist. Address book is empty.`);
    }
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

// Main function to handle user input and transfers
const main = async () => {
    populateAddressBookFromWallets();
    let continueTransfer = true;

    while (continueTransfer) {
        const addressBook = loadAddressBook();
        const transferOption = await promptUser(
            'Who would you like to transfer to?\n1: Someone new\n2: From the address book\n\nPlease enter 1 or 2: '
        );

        if (transferOption === '1') {
            const newEntryName = await promptUser('Enter the name transferring to: ');
            const newEntryAddress = await promptUser('Enter the address transferring to: ');
            const transferAmount = await promptUser('Enter the amount to transfer: ');

            // Confirmation prompt before executing transfer
            const confirmTransfer = await promptUser(
                `Are you sure you want to transfer ${transferAmount} to ${newEntryName} (${newEntryAddress})? (yes/no): `
            );

            if (confirmTransfer.toLowerCase() === 'yes') {
                executeTransfer(newEntryAddress, transferAmount);
                
                const currentAddressBook = loadAddressBook();
                const namesSet = new Set(currentAddressBook.map(entry => entry.address));
                if (!namesSet.has(newEntryAddress)) {
                    currentAddressBook.push({ name: newEntryName, address: newEntryAddress });
                    saveAddressBook(currentAddressBook);
                    console.log(`Added ${newEntryName} to the address book.`);
                } else {
                    console.log(`The address ${newEntryAddress} already exists in the address book.`);
                }
            } else {
                console.log('Transfer canceled.');
            }

        } else if (transferOption === '2') {
            if (addressBook.length === 0) {
                console.log("Address book is empty. Please add entries first.");
                continueTransfer = false;
                break;
            }

            showAddressBook(addressBook);
            const selectedEntryId = parseInt(await promptUser('Enter the ID of the person you want to transfer to: ')) - 1;

            if (selectedEntryId < 0 || selectedEntryId >= addressBook.length) {
                console.log('Invalid selection. Please try again.');
                continue;
            }

            const transferAmount = await promptUser('Enter the amount to transfer: ');

            // Confirmation prompt before executing transfer
            const confirmTransfer = await promptUser(
                `Are you sure you want to transfer ${transferAmount} to ${addressBook[selectedEntryId].name} (${addressBook[selectedEntryId].address})? (yes/no): `
            );

            if (confirmTransfer.toLowerCase() === 'yes') {
                executeTransfer(addressBook[selectedEntryId].address, transferAmount);
            } else {
                console.log('Transfer canceled.');
            }

        } else {
            console.log('Invalid option. Please choose either 1 or 2.');
            continue;
        }

        const anotherTransfer = await promptUser('Would you like to make another transfer? (yes/no): ');
        continueTransfer = anotherTransfer.toLowerCase() === 'yes';
    }

    process.stdin.pause();
    console.log('Exiting script. Have a great day!');
};

// Run the main function
main().catch(err => {
    console.error(`Error: ${err.message}`);
});
