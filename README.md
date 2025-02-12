

# X1'S THE BLACK PEARL - VALIDATOR CONSOLE BY BLACKBEARD

Welcome aboard *X1's The Black Pearl*, the interactive, automated multifunctional console designed for managing your X1 validator. Created by BLACKBEARD, this console streamlines your experience, providing tools for installation, updates, health checks, and various utilities tailored for validator management on the X1 network. You can call it **X1 Console** for short.

## Getting Started

To get started with X1's The Black Pearl (or **X1 Console**), follow these steps:

## Create a new user

1. Create a new user for your Ubuntu system and give that user 'sudo' rights.
   ## Important: Please do not use usernames 'root' or 'admin'
   
### Console Installation

1. Clone the repository and navigate to the directory:

   ```bash
   git clone https://github.com/BlackBeard085/x1console.git && cd x1console
   ```

2. Start the console:

   ```bash
   ./x1console.sh
   ```

Once X1 Console starts you will see a screen that looks like this 

![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/Image0.jpg)

### Installing X1

To install and start your X1 validator, Navigate to the 'Other' menu after starting the console:

1. From the main menu, choose option **10. Other**.
2. Next, select option **1. Install, Start X1 and Pinger**.

If you have no Wallets you wish to use reply 'no' when asked if you have existing wallets.
Once the validator and all dependencies are installed you will see the following screen which shows a few details regarding your validator.

![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/Image1.jpg)

For first installs please do the following.

IMPORTANT: Close and reopen your terminal to apply the PATH changes or run the following in your existing shell:

```bash
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
```

IMPORTANT: Once console has delegated stake and started it will take effect on the following epoch. Check logs through option 2 and make sure it is running and check x1val.online to make sure your validator is showing. it may take a minute or two for your validator to show active status when the active stake takes effect.

This option also works as your reset. By keeping your original wallets, this will reset your whole validator without deleting your wallets.

### Health Check

Option 1 from the main menu is **Health Check and Start**. This acts as your validator monitor. It checks the status of your validator, informing you if it is 'Active' or 'Delinquent'.

- If your validator is active, no action is taken.
- If your validator is delinquent, the X1 console will automatically check aspects of your validator to determine what is wrong.
  - If your stake or identity balances are under 1 XN, it will fund them by 2 XN by default, which is enough to start a validator.
  - If your stake or vote accounts are not registered, it will register them.
  - If they have been funded beforehand and cannot be used as stake or vote accounts, it will replace them.
  - If you have 0 delegated stake, it will delegate your stake.

Once it has corrected any errors, it will restart the validator.

### Validator

Option 2 from the main menu is **Validator**. This section provides three sub-options for more control over your X1 validator:

1. **Start or Restart the Validator**: Start and restart your validator without a health check.
2. **Stop the Validator**: Temporarily halt your validator operations.
3. **Show Validator Logs**: View the logs generated by your validator for monitoring and debugging purposes.
4. **Delete Validator Logs**: Remove the existing logs to free up space or for privacy concerns.

### Check Balances

Option 3 from the main menu is **Check Balances**. This option allows you to check your balances in all four wallets: **id.json**, **identity.json**, **vote.json**, and **stake.json**. 

- It also includes an added function that automatically funds underfunded vote or stake accounts if their funds drop under 1 XN.

### Transfers
 
Option 4 is **Transfers**, which allows you to transfer funds between wallets and manage an address book, adding or removing addresses from your address book.

### Manage Stake

Option 5 allows you mamage upto 5 stake wallets. Your stakes list will show you how many stake walletes you have. You can create new stake wallets in your .config/solana directory if you have less than 5 using **Add New Stake Account** option. **Merge** option allows you to merge two stake accounts into one, closing one of the stake accounts. The closed stake account will show "Account for repurposing" in your list of stakes. **Repurpose Old Stake Account** will allow you to repurpose the closed stake account into a new stake. Stake manager gives you the ability to activate or deactivate your any of your stakes and check the epoch when these changes will take effect. 
The stakes list will show you each stake wallets balance breakdown, showimg staked and unstaked balance.


![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/Image2.jpg)

### Withdraw Stake/Vote/Identity

Option 6 allows you to **Withdraw Stake/Vote/Identity**, enabling you to withdraw any unstaked balance in your stake account and any balance in your vote and identity accounts.

### Ledger

Option 7 allows you to **Monitor Ledger**, checking if it is active. In cases of fatal crashes or ledger failures, this option enables you to remove the ledger for a smoother restart.

### Set Commission

Option 8 allows you to **Set Commission**, with the default commission set at 10%. You can easily adjust this by entering your desired commission rate, and it will automatically be set once a value has been entered.

### Publish Validator

Option 9 allows you to **Publish Validator**. This option lets you register your validator. The console will prompt you for:
- The name you wish to give to your validator.
- The web URL tied to your validator, such as your X account.
- An image you wish to use as an icon for your validator.

The console will then register your details on the X1 blockchain, making this information visible on x1val.online.

### Other Menu

The **Other Menu** is reserved for functions that will be used rarely. It includes the following options:

1. **First Install and Reset**: This option serves as your initial installation and reset while allowing you to keep your wallets.
2. **Update Server and Rebuild Validator**: This option allows you to update your server and rebuild your validator, also providing the option to update the X1 console.
3. **Autopilot** 
4.
5. **Reset Pinger**: This option resets your Pinger settings.
6. **Speedtest**: This option carries out a speed test to evaluate your network performance.


## Official Links

- [X1 Official Website](https://x1.xyz/)
- [X1 Documentation](https://docs.x1.xyz/)
- [Founder Jack Levin](https://x.com/mrJackLevin)
- [Validators Portal](https://x1val.online/)

## License

This project is licensed under the MIT License. See the LICENSE file for more details.

---

For further inquiries or contributions, feel free to reach out via GitHub or engage with the community supporting X1's The Black Pearl. Happy validating! ⚓ 
