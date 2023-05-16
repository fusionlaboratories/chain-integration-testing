{ nixpkgs ? fetchTarball {
    url = "https://github.com/hercules-ci/nixpkgs/archive/e39a5efc4504099194032dfabdf60a0c4c78f181.tar.gz";
    sha256 = "1qf76qpf82889q1kfjmgjm5i7wasd4w7z77gw377x4x4jkk8fbda";
  }
}:
let
  pkgsHost = import nixpkgs {};
  pkgsGuest = import nixpkgs { system = "aarch64-linux"; };
in
pkgsHost.nixosTest {
  name = "hello_world_test";
  nodes.hello_world.nixpkgs.pkgs = pkgsGuest;
  nodes.hello_world.virtualisation.host.pkgs = pkgsHost;
  testScript = ''
    hello_world.start()
    hello_world.wait_for_unit('network.target') 
  '';
}