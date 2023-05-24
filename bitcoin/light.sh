#!/bin/sh

cd bitcoin/src


./bitcoin-cli -regtest createwallet "test"
ADDR=$(./bitcoin-cli  getnewaddress "" bech32)
PUBKEY=$(./bitcoin-cli getaddressinfo $ADDR | jq -r .pubkey)

LENX2=$(printf $PUBKEY | wc -c)
LEN=$((LENX2/2))
LENHEX=$(echo "obase=16; $LEN" | bc)
SCRIPT=$(echo 51'1'${LENHEX}${PUBKEY}51ae)

cat <<EOF
ADDR=$ADDR
PRIVKEY=$PRIVKEY
PUBKEY=$PUBKEY
SCRIPT=$SCRIPT
EOF

datadir=$HOME/signet-custom-$$
mkdir $datadir
cat > $datadir/bitcoin.conf <<EOF
signet=1
[signet]
daemon=1
signetchallenge=$SCRIPT
EOF


./bitcoind -datadir=$datadir 

printf "Waiting for custom Signet bitcoind to start"
while ! ./bitcoin-cli -datadir=$datadir getconnectioncount 2>/dev/null 1>&2
do printf .; sleep 1
done; echo

NADDR=$(./bitcoin-cli -datadir=$datadir getnewaddress)
printf "Run signet issuer"
NBITS=$(../contrib/signet/miner --cli=./bitcoin-cli calibrate --grind-cmd="./bitcoin-util grind" --seconds=600)
../contrib/signet/miner --cli=./bitcoin-cli -datadir=$datadir generate --address $ADDR --grind-cmd="./bitcoin-util grind" --nbits=$NBITS --set-block-time=$(date +%s)
../contrib/signet/miner --cli=./bitcoin-cli -datadir=$datadir generate --address $ADDR --grind-cmd="./bitcoin-util grind" --nbits=$NBITS --ongoing