const fs = require('fs');
const path = require('path');

const addressBookPath = path.join(__dirname, 'addressbook.json');

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

// Function to save the address book
const saveAddressBook = (addressBook) => {
    fs.writeFileSync(addressBookPath, JSON.stringify(addressBook, null, 2)); // Pretty print format
};

// Function to display the address book
const displayAddressBook = (addressBook) => {
    console.log("\nCurrent Address Book:");
    console.log("ID\tName                Address                          ");
    console.log("------------------------------------------------------------------------");

    addressBook.forEach((entry, index) => {
        const nameColumn = entry.name.padEnd(20, ' ');  // Ensures name is 20 characters long
        const addressColumn = entry.address.length > 45 
            ? entry.address.substr(0, 45) + '' 
            : entry.address.padEnd(45, ' '); // Ensures address is 30 characters long
        
        console.log(`${index + 1}\t${nameColumn}${addressColumn}`);
    });

    console.log("------------------------------------------------------------------------");
};

// Main function to handle user input and address book operations
const main = async () => {
    let addressBook = loadAddressBook();

    while (true) {
        displayAddressBook(addressBook);

        const action = await promptUser(
            '\nWhat would you like to do?\n1: Add address to the address book\n2: Delete address from the address book\n3: Exit\n\nPlease enter 1, 2, or 3: '
        );

        if (action === '1') {
            const newEntryName = await promptUser('Enter the name: ');
            const newEntryAddress = await promptUser('Enter the address: ');
            addressBook.push({ name: newEntryName, address: newEntryAddress });
            saveAddressBook(addressBook);
            console.log(`Added ${newEntryName} to the address book.`);

        } else if (action === '2') {
            const entryNameToRemove = await promptUser('Enter the name of the address to be removed: ');
            const initialLength = addressBook.length;
            addressBook = addressBook.filter(entry => entry.name.toLowerCase() !== entryNameToRemove.toLowerCase());
            
            if (addressBook.length < initialLength) {
                saveAddressBook(addressBook);
                console.log(`Removed ${entryNameToRemove} from the address book.`);
            } else {
                console.log(`No entry found with the name ${entryNameToRemove}.`);
            }

        } else if (action === '3') {
            console.log('Exiting address book management.');
            process.stdin.pause();
            break; // Exit the loop and terminate the script
        } else {
            console.log('Invalid option. Please choose either 1, 2, or 3.');
        }
    }
};

// Run the main function
main().catch(err => {
    console.error(`Error: ${err.message}`);
});
