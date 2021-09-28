#!/bin/sh
set -e
mkdir -p address
cd address
set -x

# Generate the necessary keys
cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/0/0 \
--hw-signing-file payment-ledger.hwsfile \
--verification-key-file payment-ledger.vkey

# Don't overwrite existing cardano-cli generate keys
if [ ! -f payment-cli.vkey ] || [ ! -f payment-cli.skey ]; then
  cardano-cli address key-gen \
  --normal-key \
  --verification-key-file payment-cli.vkey \
  --signing-key-file payment-cli.skey
fi

cat >payment.script <<EOF
{
  "type": "all",
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment-ledger.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file payment-cli.vkey)"
    }
  ]
}
EOF

cardano-hw-cli address key-gen \
--path 1854H/1815H/0H/2/0 \
--hw-signing-file stake-ledger.hwsfile \
--verification-key-file stake-ledger.vkey

# Don't overwrite existing cardano-cli generated keys
if [ ! -f stake-cli.vkey ] || [ ! -f stake-cli.skey ]; then
  cardano-cli stake-address key-gen \
  --verification-key-file stake-cli.vkey \
  --signing-key-file stake-cli.skey
fi

cat >stake.script <<EOF
{
  "type": "all",
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli stake-address key-hash --stake-verification-key-file stake-ledger.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli stake-address key-hash --stake-verification-key-file stake-cli.vkey)"
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

