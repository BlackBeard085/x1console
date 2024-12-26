#!/bin/bash

# Script to start the Solana validator
nohup $HOME/.local/share/solana/install/active_release/bin/solana-validator \
    --identity ~/.config/solana/identity.json \
    --vote-account ~/.config/solana/vote.json \
    --known-validator Abt4r6uhFs7yPwR3jT5qbnLjBtasgHkRVAd1W6H5yonT \
    --known-validator 5NfpgFCwrYzcgJkda9bRJvccycLUo3dvVQsVAK2W43Um \
    --only-known-rpc \
    --log ~/x1/log.txt \
    --ledger ~/x1/ledger \
    --rpc-port 8899 \
    --full-rpc-api \
    --dynamic-port-range 8000-8020 \
    --entrypoint xolana.xen.network:8001 \
    --entrypoint owlnet.dev:8001 \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size 50000000 \
    --enable-rpc-transaction-history \
    --enable-extended-tx-metadata-storage \
    --rpc-pubsub-enable-block-subscription \
    --full-snapshot-interval-slots 5000 \
    --maximum-incremental-snapshots-to-retain 10 \
    --maximum-full-snapshots-to-retain 50 > ~/x1/log.txt 2>&1 &
