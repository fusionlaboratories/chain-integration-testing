
{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0d1b9472176bb31fa1f9a7b86ccbb20c656e6792.tar.gz";
    sha256 = "0j7y0s691xjs2146pkssz5wd3dc5qkvzx106m911anvzd08dbx9f";
  }) {}
, devnet ? builtins.fetchTarball {
    url = "https://github.com/OffchainLabs/eth-pos-devnet/archive/93a763fef0f189dbb8c894e7eaca5513600016eb.tar.gz";
    sha256 = "1bq3870pa0jfxjgmiry89dvs0llznc2xi9jrbymx68pv29zhscxh";
  }
, bls-src ? pkgs.fetchFromGitHub {
    owner = "herumi";
    repo = "bls";
    rev = "v1.35";
    sha256 = "sha256-fHwNiZ0B5ow9GBWjO5c+rpK/jlziaMF5Bh+HQayIBUI=";
    fetchSubmodules = true;
  }
, blst-src ? pkgs.fetchFromGitHub {
    owner = "supranational";
    repo = "blst";
    rev = "v0.3.10";
    sha256 = "sha256-xero1aTe2v4IhWIJaEDUsVDOfE77dOV5zKeHWntHogY=";
  }
, prysm-src ? pkgs.fetchFromGitHub {
    owner = "prysmaticlabs";
    repo = "prysm";
    rev = "v4.0.3";
    sha256 = "sha256-pph6e1qit8fInLU1rLcCMSbXjt7ZOuR4E2fKcu0oRCY=";
  }
}:
let
  geth = pkgs.go-ethereum;
  prysm = pkgs.buildGo119Module rec {
    name = "prysm-${prysm-src.rev}";
    src = prysm-src;
    vendorHash = "sha256-JswnnPppZqzByrO+mPZSbbptMnIGWoDXVh3ucCtfjjc=";
    buildInputs = [
      (pkgs.libelf)
      (pkgs.clangStdenv.mkDerivation rec {
        name = "bls-${bls-src.rev}";
        src = bls-src;
        nativeBuildInputs = [ pkgs.cmake ];
        buildInputs = [ pkgs.gmp ];
        CFLAGS = [ "-DBLS_ETH" ];
      })
      (pkgs.stdenv.mkDerivation rec {
        name = "blst-${blst-src.rev}";
        src = blst-src;
        builder = pkgs.writeText "builder.sh" ''
          source $stdenv/setup
          buildPhase() { ./build.sh; }
          installPhase() {
            mkdir -p $out/{include/elf,lib}
            cp libblst.a $out/lib/
            cp bindings/*.{h,hpp} $out/include/
            cp build/elf/* $out/include/elf/
            cp src/*.h $out/include/
            cp src/*.c $out/include/
          }
          genericBuild
        '';
      })
    ];
    subPackages = [
      "cmd/beacon-chain"
      "cmd/client-stats"
      "cmd/prysmctl"
      "cmd/validator"
    ];
    doCheck = false;
  };

  removeNewlines = builtins.replaceStrings ["\n"] [" "];
in
pkgs.nixosTest {
  name = "ethereum-devnet";

  nodes = {
    ethereum = { config, pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [ 3500 4000 8080 8545 8551 ];

      systemd.services.create-beacon-chain-genesis = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Initialize consensus client (genesis.ssz)";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = removeNewlines ''
            ${prysm}/bin/prysmctl
            testnet
            generate-genesis
            --fork=bellatrix
            --num-validators=64
            --output-ssz=/genesis.ssz
            --chain-config-file=${devnet}/consensus/config.yml
            --geth-genesis-json-in=${devnet}/execution/genesis.json
            --geth-genesis-json-out=/genesis.json
          '';
        };
      };
      systemd.services.geth-genesis = {
        wantedBy = [ "multi-user.target" ];
        after = [ "create-beacon-chain-genesis.service" ];
        description = "Initialize execution client from genesis.json";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = removeNewlines ''
            ${geth}/bin/geth
            --datadir=/data/execution
            --password=${devnet}/execution/geth_password.txt
            init
            /genesis.json
          '';
        };
      };
      systemd.services.geth-import-account = {
        wantedBy = [ "multi-user.target" ];
        after = [ "geth-genesis.service" ];
        description = "Import account";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = removeNewlines ''
            ${geth}/bin/geth
            --datadir=/data/execution
            --password=${devnet}/execution/geth_password.txt
            account
            import
            ${devnet}/execution/sk.json
          '';
        };
      };

      systemd.services.geth = {
        wantedBy = [ "multi-user.target" ];
        after = [ "geth-import-account.service" ];
        description = "Start execution client";
        serviceConfig = {
          ExecStart = removeNewlines ''
            ${geth}/bin/geth
            --datadir=/data/execution
            --password=${devnet}/execution/geth_password.txt
            --http
            --http.api=eth
            --http.addr=0.0.0.0
            --authrpc.vhosts=*
            --authrpc.addr=0.0.0.0
            --authrpc.jwtsecret=${devnet}/jwtsecret
            --allow-insecure-unlock
            --unlock=0x123463a4b065722e99115d6c222f267d9cabb524
            --nodiscover
            --syncmode=full
          '';
        };
      };

      systemd.services.beacon-chain = {
        wantedBy = [ "multi-user.target" ];
        after = [ "geth.service" ];
        description = "Start consensus client";
        serviceConfig = {
          ExecStart = removeNewlines ''
            ${prysm}/bin/beacon-chain
            --datadir=/data/beacon-chain
            --min-sync-peers=0
            --genesis-state=/genesis.ssz
            --interop-eth1data-votes
            --bootstrap-node=
            --chain-config-file=${devnet}/consensus/config.yml
            --chain-id=32382
            --rpc-host=0.0.0.0
            --grpc-gateway-host=0.0.0.0
            --execution-endpoint=http://127.0.0.1:8551
            --accept-terms-of-use
            --jwt-secret=${devnet}/jwtsecret
            --suggested-fee-recipient=0x123463a4B065722E99115D6c222f267d9cABb524
          '';
        };
      };

      systemd.services.validator = {
        wantedBy = [ "multi-user.target" ];
        after = [ "beacon-chain.service" ];
        description = "Start validator client";
        serviceConfig = {
          ExecStart = removeNewlines ''
            ${prysm}/bin/validator
            --beacon-rpc-provider=127.0.0.1:4000
            --datadir=/data/validator
            --accept-terms-of-use
            --interop-num-validators=64
            --interop-start-index=0
            --chain-config-file=${devnet}/consensus/config.yml
          '';
        };
      };
    };
  };

  testScript = ''
    ethereum.start()
    ethereum.wait_for_open_port(8545)
    ethereum.wait_for_open_port(4000)
    ethereum.wait_for_open_port(1234) # will never happen
  '';
}