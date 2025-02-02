#!/bin/bash

echo -e "\nSetting withdrawer..."
    node "$HOME/x1console/setwithdrawer.js"

    echo -e "\nRunning health.js..."
    HEALTH_OUTPUT=$(node "$HOME/x1console/health.js")
    echo -e "$HEALTH_OUTPUT"

    if echo "$HEALTH_OUTPUT" | grep -q "WARNING"; then
        echo -e "\nWARNING issued in health check."

        # Execute checkaccounts.js before getbalances.js
        echo -e "\nForce stopping validator..."
        pkill -f tachyon-validator

        echo -e "\nRemoving ledger"
        rm -rf ~/x1/ledger

        echo -e "\nChecking accounts..."
        node "$HOME/x1console/checkaccounts.js"

        echo -e "\nChecking balances..."
        node "$HOME/x1console/getbalances.js"

        echo -e "\nChecking stake..."
        STAKE_OUTPUT=$(node "$HOME/x1console/checkstake.js")
        echo -e "$STAKE_OUTPUT"

        if echo "$STAKE_OUTPUT" | grep -q "0 active stake"; then
            echo -e "\n0 active stake found. Running activate stake..."
            node "$HOME/x1console/activatestake.js"

            echo -e "\nAttempting restart after activating stake..."
            node "$HOME/x1console/restart.js"
        else
            echo -e "\nActive stake found. Attempting restart..."
            node "$HOME/x1console/restart.js"
        fi
    else
        echo -e "\nNo WARNING issued in health check. Exiting.\n"
    fi
