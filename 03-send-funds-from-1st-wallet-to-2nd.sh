#!/usr/bin/env bash
set -e
cardano-cli query protocol-parameters \
--out-file protocol.json \
--testnet-magic 1097911063

utxo=($(cardano-cli query utxo --address "$(cat ./1st-wallet/payment.addr)" --testnet-magic 1097911063 | sed -n '3p'))

amount=5000000
deposit=2000000
if type "jq" > /dev/null; then
  deposit="$(cat protocol.json | jq .stakeAddressDeposit)"
fi
set -x

cardano-cli stake-address registration-certificate \
--stake-script-file ./1st-wallet/stake.script \
--out-file ./1st-wallet/reg.cert

cardano-cli stake-address registration-certificate \
--stake-script-file ./2nd-wallet/stake.script \
--out-file ./2nd-wallet/reg.cert

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./1st-wallet/payment.script \
--tx-out "$(cat ./1st-wallet/payment.addr)+0" \
--tx-out "$(cat ./2nd-wallet/payment.addr)+$amount" \
--certificate-file ./1st-wallet/reg.cert \
--certificate-script-file ./1st-wallet/stake.script \
--certificate-file ./2nd-wallet/reg.cert \
--certificate-script-file ./2nd-wallet/stake.script \
--fee 0 \
--out-file tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
--tx-body-file tx.draft  \
--tx-in-count 1 \
--tx-out-count 2 \
--witness-count 2 \
--byron-witness-count 0 \
--testnet-magic 1097911063 \
--protocol-params-file ./protocol.json | cut -d\  -f1)

out=$(expr "${utxo[2]}" - "$fee" - "$amount" - "$deposit" - "$deposit")

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo[0]}#${utxo[1]}" \
--tx-in-script-file ./1st-wallet/payment.script \
--tx-out "$(cat ./1st-wallet/payment.addr)+$out" \
--tx-out "$(cat ./2nd-wallet/payment.addr)+$amount" \
--certificate-file ./1st-wallet/reg.cert \
--certificate-script-file ./1st-wallet/stake.script \
--certificate-file ./2nd-wallet/reg.cert \
--certificate-script-file ./2nd-wallet/stake.script \
--fee "$fee" \
--out-file tx.raw

cardano-hw-cli transaction sign \
--tx-body-file tx.raw \
--hw-signing-file ./1st-wallet/payment0.hwsfile \
--hw-signing-file ./1st-wallet/payment1.hwsfile \
--testnet-magic 1097911063 \
--out-file tx.signed

cardano-cli transaction submit \
--tx-file tx.signed \
--testnet-magic 1097911063

set +x
mkdir -p 03-transaction
mv tx.draft tx.raw tx.signed 03-transaction

