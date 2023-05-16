{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0d1b9472176bb31fa1f9a7b86ccbb20c656e6792.tar.gz";
    sha256 = "0j7y0s691xjs2146pkssz5wd3dc5qkvzx106m911anvzd08dbx9f";
  }) {}

}:
let 
  bitcoind = pkgs.bitcoin;
  bitcoin-cli = pkgs.libbitcoin-client;
  runCommand = pkgs.runCommand;
  removeNewlines = builtins.replaceStrings ["\n"] [" "];
in
pkgs.nixosTest {
  name = "btc-signet";

  nodes = {
    btc = {config, pkgs, ...}:{
      networking.firewall.allowedTCPPorts = [38333 38332];

      systemd.services.regtest = {
       wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Generate block signing keys";
        serviceConfig = {
            type= "oneshot";
            ExecStart = removeNewlines ''
            bitcoind 
            -regtest
            -daemon 
            -wallet="test"
            '';
        };
      };
      systemd.services.regtest-credentials = {
        wantedBy = [ "multi-user.target" ];
        after = [ "regtest.service" ];
        description ="";
        serviceConfig = {
            Type="oneshot";
            ExecStart = ''      
                ADDR=$(bitcoin-cli -regtest getnewaddress) > $out/addr
                PRIVKEY=$(bitcoin-cli -regtest dumpprivkey $ADDR) > $out/privkey
                bitcoin-cli -regtest getaddressinfo $ADDR | grep pubkey > $out/pubkey
            '';
        };
      };

        # The block script is just like any old Bitcoin script, but the most common type is a k-of-n multisig. Here we will do a 1-of-1 multisig with our single pubkey above. Our script becomes
        # 51 "1" (signature count)
        # 21 Push 0x21=33 bytes (the length of our pubkey above)
        # THE_REAL_PUBKEY (our pubkey)
        # 51 "1" (pubkey count)
        # ae OP_CHECKMULTISIG opcode

      systemd.services.signet-issuer = {
        wantedBy = [ "multi-user.target" ];
        after = [ "regtest-credentials.service" ];
        description ="";
        serviceConfig = {
            ExecStart = ''
                signetchallenge=5121{$out/pubkey}51ae
                bitcoin-cli -regtest stop
                datadir=
                echo "signet=1 \n [signet] \n daemon=1 \n signetchallenge=$signetchallenge > $datadir/bitcoin.conf
                bitcoind -datadir=$datadir -wallet "test"
                bitcoin-cli -datadir=$datadir importprivkey $out/privkey
                NADDR=$(./bitcoin-cli -datadir=$datadir getnewaddress) > $out/newaddr
            '';
        };
      };
      # https://github.com/bitcoin/bitcoin/tree/master/contrib/signet
      
      systemd.services.signet-miner = {
        wantedBy = [ "multi-user.target" ];
        after = [ "signet-issuer.service" ];
        description ="";
        serviceConfig = {
            ExecStart = ''
                ...
            '';
        };
      };
    };
  };

  testScript = ''
    btc.start()
    btc.wait_for_open_port(38333)
    btc.wait_for_open_port(38332)
  '';
}