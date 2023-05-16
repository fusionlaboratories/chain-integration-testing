{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0d1b9472176bb31fa1f9a7b86ccbb20c656e6792.tar.gz";
    sha256 = "0j7y0s691xjs2146pkssz5wd3dc5qkvzx106m911anvzd08dbx9f";
  }) {}
, arbitrum ? builtins.fetchFromGitHub {
  owner = "OffchainLabs";
  repo = "nitro";
  rev = "v2.0.14";
  sha256 = "sha256-1rp4zc6926n7j9h5xkgsdpp4ghaparvzzn4mmr0by7c12msw0bhf";
  fetchSubmodules = true;
  } 
}:
let 
  brotli = pkgs.brotli;
  go-etherium = pkgs.go-etherium;
  fastcache
  blockscout

