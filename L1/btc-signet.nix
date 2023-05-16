{ pkgsHost ? import (fetchTarball {
    url = "https://github.com/hercules-ci/nixpkgs/archive/e39a5efc4504099194032dfabdf60a0c4c78f181.tar.gz";
    sha256 = "1qf76qpf82889q1kfjmgjm5i7wasd4w7z77gw377x4x4jkk8fbda";
  }) {}
, pkgsGuest ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/b68bd2ee52051aaf983a268494cb4fc6c485b646.tar.gz";
    sha256 = "0q0kkrccrx99l0v1lvqz2kvq1p0xq4szciqrvmanjw1yk30m6i47";
  }) { system = "${builtins.head (builtins.split "-" builtins.currentSystem)}-linux"; }
}:
let
  bitcoin = pkgsGuest.bitcoin;
  python = pkgsGuest.python311;
  git = pkgsGuest.git;
  jq = pkgsGuest.jq;
  bitcoin-script = import ./signet-script.nix { pkgs = pkgsGuest; };
in
pkgsHost.nixosTest {
  name = "signet-test";
  nodes.btc.nixpkgs.pkgs = pkgsGuest;
  nodes.btc.virtualisation.host.pkgs = pkgsHost;
  nodes.btc.networking.firewall.allowedTCPPorts = [38333 38332];
  nodes.btc.systemd.services.hello-world = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Bitcoin signet";
    serviceConfig = {
      #type= "oneshot";
      ExecStart = bitcoin-script;
    };
  };
  testScript = ''
    btc.start()
    btc.wait_for_open_port(38333)
    btc.wait_for_open_port(38332)
  '';
}