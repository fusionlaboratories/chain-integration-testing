{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/1e8ab5db89c84b1bb29d8d10ea60766bb5cee1f2.tar.gz";
    sha256 = "03qm2qhq8splmszbz3xwmlib4qr1xb8scm8grzqfw7s3mdw950bg";
  }) {}
, nitro-src ? pkgs.fetchFromGitHub {
    owner = "OffchainLabs";
    repo = "nitro";
    rev = "v2.0.14";
    sha256 = "sha256-RtYDRLl/31Qg7yfzfyT8idG9QIMikg3QUXzUcrbBI1Q=";
    fetchSubmodules = true;
  }
}:
let
  arbitrator = pkgs.rustPlatform.buildRustPackage {
    name = "arbitrator-${nitro-src.rev}";
    src = "${nitro-src}/arbitrator";
    cargoLock.lockFile = "${nitro-src}/arbitrator/Cargo.lock";
    buildType = "release";
    buildInputs = [ pkgs.brotli ];
    nativeBuildInputs = [ pkgs.rust-cbindgen ];
    postBuild = ''
      cbindgen --config cbindgen.toml --crate prover --output $out/include/arbitrator.h
    '';
  };
  solc = pkgs.callPackage ./solc.nix { version = "0.8.9"; };
  node_modules = pkgs.mkYarnModules {
    pname = "contracts-node_modules";
    version = nitro-src.rev;
    nodejs = pkgs.nodejs-16_x;
    packageJSON = "${nitro-src}/contracts/package.json";
    yarnLock = "${nitro-src}/contracts/yarn.lock";
    offlineCache = pkgs.fetchYarnDeps {
      yarnLock = "${nitro-src}/contracts/yarn.lock";
      sha256 = "sha256-VxLVNPZYdQO/H86PwgLpDskNEt+Z+BO8HW8K+o0HAuA=";
    };
    postBuild = ''
      cd $out/node_modules/hardhat/src/internal/util
      patch < ${./p1.patch}
      cd -
    '';
  };
  contracts = pkgs.runCommand "contracts" {
    src = "${nitro-src}/contracts";
    buildInputs = [ pkgs.nodejs-16_x.pkgs.yarn ];
  } ''
    mkdir node_modules
    cp -r ${node_modules}/node_modules/* node_modules
    ls -alh node_modules
    chmod -R a+w node_modules/**/*
    cd node_modules/hardhat/src/internal/util
    chmod -R a+w .
    cat global-dir.ts | grep getCompilersDir -A 5
    ${pkgs.patch}/bin/patch < ${./p1.patch}
    cat global-dir.ts | grep getCompilersDir -A 5
    cd -
    echo "Patched\n\n"
    rm -rf node_modules/hardhat/src

    export XDG_CACHE_HOME=$HOME/.cache
    mkdir -p "$HOME/.cache/hardhat-nodejs/compilers"
    cp -r ${solc}/* "$HOME/.cache/hardhat-nodejs/compilers"
    echo "$HOME/.cache/hardhat-nodejs/compilers/linux-amd64"
    ls "$HOME/.cache/hardhat-nodejs/compilers/linux-amd64"
    echo "${nitro-src}"
    cp -r $src/* .
    chmod 666 package.json
    patch -u -i ${./contracts.patch}
    yarn --offline build
    
  '';
  solgen = pkgs.buildGoModule {
    name = "solgen-${nitro-src.rev}";
    src = "${nitro-src}/go-ethereum";
    prePatch = ''
      mkdir -p solgen
      cp "${nitro-src}/solgen/gen.go" solgen/gen.go
    '';
    patches = [ ./solgen.patch ];
    subPackages = ["solgen"];
    vendorSha256 = "sha256-J0ZjdlXkiOPlv35BxhC15iPzvT+pAI/N7t01PcSRUe8=";
  };
  nitro = pkgs.buildGo119Module {
    name = "nitro-${nitro-src.rev}";
    src = nitro-src;
    subPackages = ["cmd/nitro"];
    proxyVendor = true;
    vendorSha256 = "sha256-OTAHTHe3UElJSxF07X2LK0okRiNKclumbJpAmj2EX4k=";
    preBuild = ''
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/bridgegen=${nitro-src}/solgen/go/bridgegen
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/challengegen=${nitro-src}/solgen/go/challengegen
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/node_interfacegen=${nitro-src}/solgen/go/node_interfacegen
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/ospgen=${nitro-src}/solgen/go/ospgen
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/precompilesgen=${nitro-src}/solgen/go/precompilesgen
      go mod edit -replace github.com/offchainlabs/nitro/solgen/go/rollupgen=${nitro-src}/solgen/go/rollupgen
    '';
  };
  brotli-wasm-builder = pkgs.stdenv.mkDerivation {
    pname = "brotli-wasm-builder";
    version = nitro-src.rev;
    src = nitro-src;
    buildInputs = [
      pkgs.emscripten
      pkgs.cmake
    ];
    cmakeFlags = [
      "-DCMAKE_C_COMPILER=${pkgs.emscripten}/bin/emcc"
      "-DCMAKE_C_FLAGS=-fPIC"
      "-DCMAKE_AR=${pkgs.emscripten}/bin/emar"
      "-DCMAKE_RANLIB=${pkgs.coreutils}/bin/touch"
    ];
    #cmake ../../ -DCMAKE_C_COMPILER=emcc -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-fPIC -DCMAKE_INSTALL_PREFIX="$TEMP_INSTALL_DIR_ABS" -DCMAKE_AR=`which emar` -DCMAKE_RANLIB=`which touch`
    #make -j
    #make install
  };
  # nitro = pkgs.stdenv.mkDerivation {
  #   pname = "nitro";
  #   version = nitro-src.rev;
  #   src = nitro-src;
  #   buildInputs = [
  #     pkgs.rust-cbindgen
  #     pkgs.cargo
  #     pkgs.emscripten
  #   ];
  # };
  # ./build-brotli.sh -w -t install/
in
pkgs.mkShell {
  buildInputs = [
    # arbitrator
    # contracts
    # solgen
    # solc
    node_modules
  ];
}
# apt-get install cmake make git lbzip2 python3 xz-utils
# https://github.com/emscripten-core/emsdk

# apt-get install -y cmake make gcc git
# cargo install --force cbindgen

# brotli-wasm-builder
