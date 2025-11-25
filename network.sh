#!/bin/bash

while true; do
    echo -e "\nWhich network would you like to connect to?"
    echo "1. X1 Mainnet"
    echo "2. X1 Testnet"
    echo "3. Custom RPC"
    echo "0. Cancel"
    read -p "Please choose an option (0-3): " option
    echo " "
    case $option in
        1)
            solana config set -u https://rpc.mainnet.x1.xyz/
            echo -e "\nConnected to X1 Mainnet."
            break
            ;;
        2)
            solana config set -u https://rpc.testnet.x1.xyz
            echo -e "\nConnected to X1 Testnet."
            break
            ;;
        3)
            read -p "Enter your custom RPC URL: " custom_rpc
            if [ -z "$custom_rpc" ]; then
                echo -e "\nInvalid input. Please enter a valid RPC URL."
            else
                solana config set -u "$custom_rpc"
                echo -e "\nConnected to custom RPC: $custom_rpc"
                break
            fi
            ;;
        0)
            echo "Operation canceled. Exiting."
            exit 0
            ;;
        *)
            echo -e "\nInvalid option. Please choose a number between 1 and 4."
            ;;
    esac
done
