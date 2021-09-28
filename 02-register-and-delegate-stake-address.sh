#!/usr/bin/env bash
set -e
cardano-cli query protocol-parameters \
--out-file protocol.json \
--testnet-magic 1097911063

utxo=($(cardano-cli query utxo --address "$(cat ./address/payment.addr)" --testnet-magic 1097911063 | sed -n '3p'))

deposit=2000000
if type "jq" > /dev/null; then
  deposit="$(jq .stakeAddressDeposit <protocol.json)"
fi

set -x

cardano-cli stake-address registration-certificate \
--stake-script-file ./address/stake.script \
--out-file ./reg.cert

cardano-cli stake-address delegation-certificate \
--stake-pool-id 001337292eec9b3eefc6802f71cb34c21a7963eb12466d52836aa390 \
--stake-script-file ./address/stake.script \
--out-file ./deleg.cert

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./address/payment.script \
--tx-out "$(cat ./address/payment.addr)"+0 \
--certificate-file ./reg.cert \
--certificate-file ./deleg.cert \
--certificate-script-file ./address/stake.script \
--fee 0 \
--out-file tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
--tx-body-file tx.draft  \
--tx-in-count 1 \
--tx-out-count 1 \
--witness-count 4 \
--testnet-magic 1097911063 \
--protocol-params-file ./protocol.json | cut -d\  -f1)

out=$(expr "${utxo[2]}" - "$deposit" - "$fee")

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./address/payment.script \
--tx-out "$(cat ./address/payment.addr)"+"$out" \
--certificate-file ./reg.cert \
--certificate-file ./deleg.cert \
--certificate-script-file ./address/stake.script \
--fee "$fee" \
--out-file tx.raw

cardano-cli transaction witness \
--tx-body-file tx.raw \
--signing-key-file ./address/payment-cli.skey \
--out-file payment-cli.witness \
--testnet-magic 1097911063

cardano-cli transaction witness \
--tx-body-file tx.raw \
--signing-key-file ./address/stake-cli.skey \
--out-file stake-cli.witness \
--testnet-magic 1097911063

cardano-hw-cli transaction witness \
--tx-body-file tx.raw \
--hw-signing-file ./address/payment-ledger.hwsfile \
--hw-signing-file ./address/stake-ledger.hwsfile \
--out-file payment-ledger.witness \
--out-file stake-ledger.witness \
--testnet-magic 1097911063

cardano-cli transaction assemble \
--tx-body-file tx.raw \
--witness-file payment-ledger.witness \
--witness-file payment-cli.witness \
--witness-file stake-ledger.witness \
--witness-file stake-cli.witness \
--out-file tx.signed

cardano-cli transaction submit \
--tx-file tx.signed \
--testnet-magic 1097911063

set +x
mkdir -p 02-transaction
mv tx.draft tx.raw tx.signed reg.cert deleg.cert *.witness 02-transaction
