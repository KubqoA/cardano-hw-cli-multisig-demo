#!/bin/sh
set -e
mkdir -p mint-policy
cd mint-policy
set -x

# Generate the necessary keys
cardano-hw-cli address key-gen \
--path 1855H/1815H/0H \
--hw-signing-file mint-ledger.hwsfile \
--verification-key-file mint-ledger.vkey

cardano-cli address key-gen \
--normal-key \
--verification-key-file mint-cli.vkey \
--signing-key-file mint-cli.skey

cat >policy.script <<EOF
{
  "type": "all",
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file mint-ledger.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file mint-cli.vkey)"
    }
  ]
}
EOF

cardano-hw-cli transaction policyid \
--script-file policy.script \
--hw-signing-file mint-ledger.hwsfile >policyId
