#!/bin/sh
set -e
mkdir -p 2nd-wallet
cd 2nd-wallet
set -x

# Generate the necessary keys
cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/0/2 \
--hw-signing-file payment2.hwsfile \
--verification-key-file payment2.vkey

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/0/3 \
--hw-signing-file payment3.hwsfile \
--verification-key-file payment3.vkey

cat >payment.script <<EOF
{
  "type": "atLeast",
  "required": 2,
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment2.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment3.vkey)"
    }
  ]
}
EOF

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/2/1 \
--hw-signing-file stake1.hwsfile \
--verification-key-file stake1.vkey

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/2/2 \
--hw-signing-file stake2.hwsfile \
--verification-key-file stake2.vkey

cat >stake.script <<EOF
{
  "type": "atLeast",
  "required": 1,
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli stake-address key-hash --stake-verification-key-file stake1.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli stake-address key-hash --stake-verification-key-file stake2.vkey)"
    }
  ]
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
