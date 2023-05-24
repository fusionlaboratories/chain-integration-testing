# Chaingremlin chains


## Chains 
- Etherium POS
- Bitcoin Signet
- Arbitrum 
- Polygon POS



https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests


Running: 

builder VM: 
````
QEMU_OPTS="-m 8192" nix run --option sandbox false nixpkgs#darwin.builder
````

run eth devnet: 

nix-build --option sandbox false etherium/etherium-devnet.nix