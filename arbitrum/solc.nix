{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/1e8ab5db89c84b1bb29d8d10ea60766bb5cee1f2.tar.gz";
    sha256 = "03qm2qhq8splmszbz3xwmlib4qr1xb8scm8grzqfw7s3mdw950bg";
  }) {}
, system ? builtins.currentSystem
, version ? "0.8.20"
}:
let
  arch-mapping = { "x86_64-linux" = "linux-amd64"; };
  arch = arch-mapping."${system}";
  builds-file = ./. + "/${arch}.json";
  build = builtins.head (
    builtins.filter (b: b.version == version) (
      builtins.fromJSON (builtins.readFile (builds-file))
    ).builds
  );
  solc-binary = pkgs.fetchurl {
    name = "solc-${version}-raw";
    url = "https://binaries.soliditylang.org/${arch}/${build.path}";
    sha256 = pkgs.lib.strings.removePrefix "0x" build.sha256;
  };
in
pkgs.runCommand "solc-${version}" {} ''
  mkdir -p $out/${arch}
  cp "${builds-file}" $out/${arch}/list.json
  cp "${solc-binary}" $out/${arch}/${build.path}
''
