#!/bin/sh

cd bitcoin/src

#./bitcoin-cli -regtest createwallet test
./bitcoind -regtest -daemon
./bitcoin-cli -regtest generatetoaddress 101 $(./bitcoin-cli -regtest getnewaddress)

printf "Waiting for regtest bitcoind to start"
while ! ./bitcoin-cli -regtest -datadir=$datadir getconnectioncount 2>/dev/null 1>&2
do printf .; sleep 1
done; echo

ADDR=$(./bitcoin-cli -regtest getnewaddress "" bech32)
PRIVKEY=$(./bitcoin-cli -regtest dumpprivkey $ADDR)
PUBKEY=$(./bitcoin-cli -regtest getaddressinfo $ADDR | jq -r .pubkey)

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

./bitcoin-cli -regtest stop 2>&1

./bitcoind -datadir=$datadir -wallet="test"

printf "Waiting for custom Signet bitcoind to start"
while ! ./bitcoin-cli -datadir=$datadir getconnectioncount 2>/dev/null 1>&2
do printf .; sleep 1
done; echo

./bitcoin-cli -datadir=$datadir importprivkey "$PRIVKEY"
./bitcoind -datadir=$datadir -wallet="test"
./bitcoin-cli -datadir=$datadir importprivkey $PRIVKEY

NADDR=$(./bitcoin-cli -datadir=$datadir getnewaddress)
printf "Run signet issuer"
NBITS=$(../contrib/signet/miner --cli=./bitcoin-cli calibrate --grind-cmd="./bitcoin-util grind" --seconds=600)
../contrib/signet/miner --cli=./bitcoin-cli -datadir=$datadir generate --address $ADDR --grind-cmd="./bitcoin-util grind" --nbits=$NBITS --set-block-time=$(date +%s)
../contrib/signet/miner --cli=./bitcoin-cli -datadir=$datadir generate --address $ADDR --grind-cmd="./bitcoin-util grind" --nbits=$NBITS --ongoing