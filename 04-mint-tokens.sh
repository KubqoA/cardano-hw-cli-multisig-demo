#!/usr/bin/env bash
set -e
cardano-cli query protocol-parameters \
--out-file protocol.json \
--testnet-magic 1097911063

utxo=($(cardano-cli query utxo --address "$(cat ./address/payment.addr)" --testnet-magic 1097911063 | sed -n '3p'))
mintamount=1000000
tokenname="VaccumTokens"

set -x

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./address/payment.script \
--tx-out "$(cat ./address/payment.addr)"+0+"$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--mint "$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--minting-script-file ./mint-policy/policy.script \
--fee 0 \
--out-file tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
--tx-body-file tx.draft  \
--tx-in-count 1 \
--tx-out-count 1 \
--witness-count 4 \
--testnet-magic 1097911063 \
--protocol-params-file ./protocol.json | cut -d\  -f1)

out=$(expr "${utxo[2]}" - "$fee")

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./address/payment.script \
--tx-out "$(cat ./address/payment.addr)"+"$out"+"$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--mint "$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--minting-script-file ./mint-policy/policy.script \
--fee "$fee" \
--out-file tx.raw

cardano-cli transaction witness \
--tx-body-file tx.raw \
--signing-key-file ./address/payment-cli.skey \
--out-file payment-cli.witness \
--testnet-magic 1097911063

cardano-cli transaction witness \
--tx-body-file tx.raw \
--signing-key-file ./mint-policy/mint-cli.skey \
--out-file mint-cli.witness \
--testnet-magic 1097911063

cardano-hw-cli transaction witness \
--tx-body-file tx.raw \
--hw-signing-file ./address/payment-ledger.hwsfile \
--hw-signing-file ./mint-policy/mint-ledger.hwsfile \
--out-file payment-ledger.witness \
--out-file mint-ledger.witness \
--testnet-magic 1097911063

cardano-cli transaction assemble \
--tx-body-file tx.raw \
--witness-file payment-ledger.witness \
--witness-file payment-cli.witness \
--witness-file mint-ledger.witness \
--witness-file mint-cli.witness \
--out-file tx.signed

cardano-cli transaction submit \
--tx-file tx.signed \
--testnet-magic 1097911063

set +x
mkdir -p 04-transaction
mv tx.draft tx.raw tx.signed *.witness 04-transaction
