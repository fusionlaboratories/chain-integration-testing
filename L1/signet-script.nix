{ pkgs }: pkgs.writeScript "signet.sh" ''
#!/bin/sh
"${pkgs.git}/bin/git" clone https://github.com/bitcoin/bitcoin.git
cd bitcoin/src

"${pkgs.bitcoind}/bin/bitcoin-cli" -regtest -datadir=$datadir createwallet test
printf "Waiting for regtest bitcoind to start"
while ! "${pkgs.bitcoind}/bin/bitcoin-cli" -regtest -datadir=$datadir getconnectioncount 2>/dev/null 1>&2
do printf .; sleep 1
done; echo

ADDR=$("${pkgs.bitcoind}/bin/bitcoin-cli" -regtest getnewaddress "" bech32)
PRIVKEY=$("${pkgs.bitcoind}/bin/bitcoin-cli" -regtest dumpprivkey $ADDR)
PUBKEY=$("${pkgs.bitcoind}/bin/bitcoin-cli" -regtest getaddressinfo $ADDR | "${pkgs.jq}/bin/jq" -r .pubkey)

LENX2=$(printf $PUBKEY | wc -c)
LEN=$((LENX2/2))
LENHEX=$(echo "obase=16; $LEN" | bc)
SCRIPT=$(echo 51''${LENHEX}''${PUBKEY}51ae)

cat <<EOF
ADDR=$ADDR
PRIVKEY=$PRIVKEY
PUBKEY=$PUBKEY
SCRIPT=$SCRIPT
EOF

"${pkgs.bitcoind}/bin/bitcoin-cli" -regtest stop 2>&1

datadir=$HOME/signet-custom-$$
mkdir $datadir
cat > $datadir/bitcoin.conf <<EOF
signet=1
[signet]
daemon=1
signetchallenge=$SCRIPT
EOF
"${pkgs.bitcoind}/bin/bitcoind" -datadir=$datadir -wallet="test"

printf "Waiting for custom Signet bitcoind to start"
while ! "${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir getconnectioncount 2>/dev/null 1>&2
do printf .; sleep 1
done; echo

"${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir importprivkey "$PRIVKEY"
"${pkgs.bitcoind}/bin/bitcoind" -datadir=$datadir -wallet="test"
"${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir importprivkey $PRIVKEY

NADDR=$("${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir getnewaddress)
printf "Run signet issuer"
NBITS=$(../contrib/signet/miner --cli="${pkgs.bitcoind}/bin/bitcoin-cli" calibrate --grind-cmd="${pkgs.bitcoind}/bin/bitcoin-util grind" --seconds=600)
../contrib/signet/miner --cli="${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir generate --address $ADDR --grind-cmd="${pkgs.bitcoind}/bin/bitcoin-util grind" --nbits=$NBITS --set-block-time=$(date +%s)
../contrib/signet/miner --cli="${pkgs.bitcoind}/bin/bitcoin-cli" -datadir=$datadir generate --address $ADDR --grind-cmd="${pkgs.bitcoind}/bin/bitcoin-util grind" --nbits=$NBITS --ongoing
''