#!/usr/bin/env bash
set -e
cardano-cli query protocol-parameters \
--out-file protocol.json \
--testnet-magic 1097911063

utxo1=($(cardano-cli query utxo --address "$(cat ./1st-wallet/payment.addr)" --testnet-magic 1097911063 | sed -n '3p'))
utxo2=($(cardano-cli query utxo --address "$(cat ./2nd-wallet/payment.addr)" --testnet-magic 1097911063 | sed -n '3p'))

deposit=2000000
if type "jq" > /dev/null; then
  deposit="$(jq .stakeAddressDeposit <protocol.json)"
fi

wallet1TokenAmount=600000
wallet2TokenAmount=400000
mintamount=$((wallet1TokenAmount + wallet2TokenAmount))
tokenname="T0ken"
set -x

cardano-cli stake-address deregistration-certificate \
--stake-script-file ./1st-wallet/stake.script \
--out-file ./1st-wallet/dereg.cert

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo1[0]}#${utxo1[1]}" \
--tx-in-script-file ./1st-wallet/payment.script \
--tx-in "${utxo2[0]}#${utxo2[1]}" \
--tx-in-script-file ./2nd-wallet/payment.script \
--tx-out "$(cat ./1st-wallet/payment.addr)"+0+"$wallet1TokenAmount $(cat ./mint-policy/policyId).$tokenname" \
--tx-out "$(cat ./2nd-wallet/payment.addr)"+0+"$wallet2TokenAmount $(cat ./mint-policy/policyId).$tokenname" \
--withdrawal "$(cat ./1st-wallet/stake.addr)"+0 \
--withdrawal-script-file ./1st-wallet/stake.script \
--withdrawal "$(cat ./2nd-wallet/stake.addr)"+0 \
--withdrawal-script-file ./2nd-wallet/stake.script \
--certificate-file ./1st-wallet/dereg.cert \
--certificate-script-file ./1st-wallet/stake.script \
--mint "$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--minting-script-file ./mint-policy/policy.script \
--fee 0 \
--out-file tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
--tx-body-file tx.draft  \
--tx-in-count 2 \
--tx-out-count 2 \
--witness-count 8 \
--byron-witness-count 0 \
--testnet-magic 1097911063 \
--protocol-params-file ./protocol.json | cut -d\  -f1)

out1=$(expr "${utxo1[2]}" + "$deposit" - "$fee")
out2=$(expr "${utxo2[2]}")

cardano-cli transaction build-raw \
--mary-era \
--tx-in "${utxo1[0]}#${utxo1[1]}" \
--tx-in-script-file ./1st-wallet/payment.script \
--tx-in "${utxo2[0]}#${utxo2[1]}" \
--tx-in-script-file ./2nd-wallet/payment.script \
--tx-out "$(cat ./1st-wallet/payment.addr)"+"$out1"+"$wallet1TokenAmount $(cat ./mint-policy/policyId).$tokenname" \
--tx-out "$(cat ./2nd-wallet/payment.addr)"+"$out2"+"$wallet2TokenAmount $(cat ./mint-policy/policyId).$tokenname" \
--withdrawal "$(cat ./1st-wallet/stake.addr)"+0 \
--withdrawal-script-file ./1st-wallet/stake.script \
--withdrawal "$(cat ./2nd-wallet/stake.addr)"+0 \
--withdrawal-script-file ./2nd-wallet/stake.script \
--certificate-file ./1st-wallet/dereg.cert \
--certificate-script-file ./1st-wallet/stake.script \
--mint "$mintamount $(cat ./mint-policy/policyId).$tokenname" \
--minting-script-file ./mint-policy/policy.script \
--fee "$fee" \
--out-file tx.raw

cardano-hw-cli transaction sign \
--tx-body-file tx.raw \
--hw-signing-file ./1st-wallet/payment0.hwsfile \
--hw-signing-file ./1st-wallet/payment1.hwsfile \
--hw-signing-file ./1st-wallet/stake0.hwsfile \
--hw-signing-file ./2nd-wallet/payment2.hwsfile \
--hw-signing-file ./2nd-wallet/payment3.hwsfile \
--hw-signing-file ./2nd-wallet/stake2.hwsfile \
--hw-signing-file ./mint-policy/mint0.hwsfile \
--hw-signing-file ./mint-policy/mint1.hwsfile \
--testnet-magic 1097911063 \
--out-file tx.signed

cardano-cli transaction submit \
--tx-file tx.signed \
--testnet-magic 1097911063

set +x
mkdir -p 05-transaction
mv tx.draft tx.raw tx.signed 05-transaction

