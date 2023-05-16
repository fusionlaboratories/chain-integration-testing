# https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests
# https://nix.dev/tutorials/integration-testing-using-virtual-machines
# https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
{ test, pkgs ? import <nixpkgs> {} }:

pkgs.nixosTest {
  name = "${test}";
  nodes = import (./. + "/${test}/test.nix");
  testScript = builtins.readFile (./. +  "/${test}/test.py");
  skipLint = true;
}
