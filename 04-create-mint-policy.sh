#!/bin/sh
set -e
mkdir -p mint-policy
cd mint-policy
set -x

# Generate the necessary keys
cardano-hw-cli address key-gen \
--path 1855H/1815H/0H \
--hw-signing-file mint0.hwsfile \
--verification-key-file mint0.vkey

cardano-hw-cli address key-gen \
--path 1855H/1815H/1H \
--hw-signing-file mint1.hwsfile \
--verification-key-file mint1.vkey

cat >policy.script <<EOF
{
  "type": "all",
  "scripts": [
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file mint0.vkey)"
    },
    {
      "type": "sig",
      "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file mint1.vkey)"
    }
  ]
}
EOF

cardano-hw-cli transaction policyid \
--script-file policy.script \
--hw-signing-file mint0.hwsfile \
--hw-signing-file mint1.hwsfile >policyId
