#!/bin/bash

# Script to start the Solana validator
nohup $HOME/.local/share/solana/install/active_release/bin/solana-validator \
    --identity ~/.config/solana/identity.json \
    --vote-account ~/.config/solana/vote.json \
    --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT \
    --known-validator FcrZRBfVk2h634L9yvkysJdmvdAprq1NM4u263NuR6LC \
    --known-validator Tpsu5EYTJAXAat19VEh54zuauHvUBuryivSFRC3RiFk \
    --only-known-rpc \
    --log ~/x1/log.txt \
    --ledger ~/x1/ledger \
    --minimal-snapshot-download-speed 5000000 \
    --rpc-port 8899 \
    --full-rpc-api \
    --dynamic-port-range 8000-8020 \
    --entrypoint entrypoint1.testnet.x1.xyz:8001 \
    --entrypoint entrypoint2.testnet.x1.xyz:8000 \
    --entrypoint entrypoint3.testnet.x1.xyz:8000 \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size 50000000 \
    --enable-rpc-transaction-history \
    --enable-extended-tx-metadata-storage \
    --rpc-pubsub-enable-block-subscription \
    --full-snapshot-interval-slots 5000 \
    --maximum-incremental-snapshots-to-retain 10 \
    --maximum-full-snapshots-to-retain 50 > ~/x1/log.txt 2>&1 &
