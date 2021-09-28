#!/bin/sh
set -e
mkdir -p 1st-wallet
cd 1st-wallet
set -x

# Generate the necessary keys
cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/0/0 \
--hw-signing-file payment0.hwsfile \
--verification-key-file payment0.vkey

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/0/1 \
--hw-signing-file payment1.hwsfile \
--verification-key-file payment1.vkey

cat >payment.script <<EOF
{
  "type": "all",
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment0.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment1.vkey)"
    }
  ]
}
EOF

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/2/0 \
--hw-signing-file stake0.hwsfile \
--verification-key-file stake0.vkey

cat >stake.script <<EOF
{
  "type": "sig",
  "keyHash": "$(cardano-cli stake-address key-hash --stake-verification-key-file stake0.vkey)"
}
EOF

# Build the final address
cardano-cli address build \
--payment-script-file payment.script \
--stake-script-file stake.script \
--out-file payment.addr \
--testnet-magic 1097911063

cardano-cli query utxo \
--address "$(cat payment.addr)" \
--testnet-magic 1097911063

set +x

if [ ! -f stake.addr ]; then
  cardano-cli transaction policyid --script-file stake.script | bech32 script | cardano-address address stake --network-tag testnet >stake.addr
fi

