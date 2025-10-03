#!/bin/bash

while true; do
    echo -e "\nWhich network would you like to connect to?"
    echo "1. Mainnet"
    echo "2. Testnet"
    read -p "Please choose an option (1 or 2): " option
    echo " "
    case $option in
        1)
            solana config set -u https://rpc.mainnet.x1.xyz/
            echo -e "\nConnected to Mainnet."
            break
            ;;
        2)
            solana config set -u https://rpc.testnet.x1.xyz
            echo -e "\nConnected to Testnet."
            break
            ;;
        *)
            echo -e "\nInvalid option. Please choose either 1 or 2."
            ;;
    esac
done
