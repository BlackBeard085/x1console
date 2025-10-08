#!/bin/bash

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"

# Script to start the tachyon validator

# Path to the wallets.json file
WALLETS_JSON=~/x1console/wallets.json

# Extract the Vote account address from wallets.json
VOTE_ACCOUNT=$(jq -r '.[] | select(.name == "Vote") | .address' "$WALLETS_JSON")

# Check if the VOTE_ACCOUNT was successfully extracted
if [ -z "$VOTE_ACCOUNT" ]; then
    echo "Error: Vote account address could not be found in $WALLETS_JSON."
    exit 1
fi

# Start the validator
nohup $HOME/.local/share/solana/install/active_release/bin/tachyon-validator \
    --identity ~/.config/solana/identity.json \
    --vote-account "$VOTE_ACCOUNT" \
    --known-validator 7ufaUVtQKzGu5tpFtii9Cg8kR4jcpjQSXwsF3oVPSMZA \
    --known-validator 5Rzytnub9yGTFHqSmauFLsAbdXFbehMwPBLiuEgKajUN \
    --known-validator 4V2QkkWce8bwTzvvwPiNRNQ4W433ZsGQi9aWU12Q8uBF \
    --known-validator CkMwg4TM6jaSC5rJALQjvLc51XFY5pJ1H9f1Tmu5Qdxs \
    --known-validator 7J5wJaH55ZYjCCmCMt7Gb3QL6FGFmjz5U8b6NcbzfoTy \
    --accounts /run/accounts \
    --accounts-db-cache-limit-mb 10000 \
    --only-known-rpc \
    --log ~/x1/log.txt \
    --ledger ~/x1/ledger \
    --minimal-snapshot-download-speed 5000000 \
    --rpc-port 8899 \
    --full-rpc-api \
    --dynamic-port-range 8000-8020 \
    --entrypoint entrypoint0.mainnet.x1.xyz:8001 \
    --entrypoint entrypoint1.mainnet.x1.xyz:8001 \
    --entrypoint entrypoint2.mainnet.x1.xyz:8001 \
    --entrypoint entrypoint3.mainnet.x1.xyz:8001 \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size 50000000 \
    --enable-rpc-transaction-history \
    --enable-extended-tx-metadata-storage \
    --rpc-pubsub-enable-block-subscription \
    --full-snapshot-interval-slots 5000 \
    --maximum-incremental-snapshots-to-retain 10 \
    --maximum-full-snapshots-to-retain 50 > ~/x1/log.txt 2>&1 &

