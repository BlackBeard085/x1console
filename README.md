# X1'S THE BLACK PEARL - VALIDATOR CONSOLE BY BLACKBEARD

Welcome aboard *X1's The Black Pearl*, the interactive, automated multifunctional console designed for managing your X1 validator. Created by BLACKBEARD, this console streamlines your experience, providing tools for installation, updates, health checks, and various utilities tailored for validator management on the Solana network. You can call it **X1 Console** for short.

## Features

- **Installation and Setup**: Easily install and configure your X1 validator, ensuring seamless integration with your existing wallets. The console automates the installation process, tuning the system for a X1 validator, installing the the X1 compatible CLI, builds the agave validator, opens the required ports, connects to the X1 network, creates four new X1 wallets or uses your exisying wallets if you prefer, starts your validator, funds your id.json (withdrawer) which funds your identity, it registers both your stake.json and vot.json, delegates your stake and restarts your validator. it then installs and starts Pinger. ALL IN ONE COMMAND. streamlining the process so anyone can become an X1 validator.
- **Update Utilities**: Keep your validator and console up to date with minimal effort.
- **Health Monitoring**: Perform automated health checks and take appropriate action where needed to bring a delinquent validator tonactive status again. AN AUTOMATED TROUBLESHOOTER IN EFFECT
- **Publish Validator**: Publish your validator so it becomes visible on X1Val.online, just enter you validator name, web URL - eg: X account and image URL and let it do the rest. The web URL and image can be left blank.
- **Account Management**: Utilities to set commission, check balances, and manage validator logs.
- **Interactive Command-Line Interface**: User-friendly interface allowing easy navigation through various functionalities.
- **Integrated Ledger Management**: Monitor or remove your ledger as necessary.

## Getting Started

To get started with X1's The Black Pearl (or **X1 Console**), follow these steps:

### Installation

1. Clone the repository and navigate to the directory:

   ```bash
   git clone https://github.com/BlackBeard085/x1console.git && cd x1console
   ```

2. Start the console:

   ```bash
   ./x1console.sh
   ```

## Functions Overview

- **check_npm_package**: Checks if a Node.js package is installed; installs if not.
- **check_agave_directory**: Checks for the existence of the X1 agave-xolana directory and handles user options for deletion or archiving.
- **install**: Installs the X1 validator setup, managing wallet configurations.
- **update_x1**: Updates the Solana CLI and the validator application, ensuring the latest features and fixes are applied.
- **update_x1_console**: Updates the X1 console itself to the latest version.
- **health_check**: Conducts health checks on the validator and initiates corrective actions if needed.
- **balances**: Retrieves and displays balance information for the configured accounts.
- **publish_validator**: Publishes validator information on the X1 network.
- **pinger**: Manages the pinging process for the validator and fetches ping statistics.
- **show_logs**: Displays logs from the validator for monitoring purposes.
- **delete_logs**: Safely deletes validator log files.
- **ledger**: Monitors or removes the ledger corresponding to the validator.
- **set_commission**: Configures commission percentages for your validator.
- **exit_script**: Safely exits the console.

### User Interaction Loop

The console operates in a command loop, allowing users to perform actions such as installation, updates, health checks, and more based on user input.

## Official Links

- [X1 Official Website](https://x1.xyz/)
- [X1 Documentation](https://docs.x1.xyz/)
- [Founder Jack Levin](https://x.com/mrJackLevin)
- [Validators Portal](https://x1val.online/)

## License

This project is licensed under the MIT License. See the LICENSE file for more details.

---

For further inquiries or contributions, feel free to reach out via GitHub or engage with the community supporting X1's The Black Pearl. Happy validating! ⚓
