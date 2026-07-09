# nix-contract

Eval-time visible, build-checked contracts for Nix derivations.

## Overview

Sometimes you wish to know what files your derivation produces without instantiating it.
Declare them in advance with nix-contract. They will be checked once the derivation is built.

## Usage

Add this flake as an input.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-contract.url = "github:421anon/nix-contract";
  };

  outputs = { nixpkgs, nix-contract, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      withContract = nix-contract.lib.withContract {
        inherit pkgs;
        inherit (pkgs) lib;
      };
    in {
      packages.${system}.example = withContract {
        out.files = [ "share/example/data.txt" ];
      } (pkgs.stdenv.mkDerivation {
        pname = "example";
        version = "1.0.0";

        dontUnpack = true;

        installPhase = ''
          mkdir -p "$out/share/example"
          cp ./data.txt "$out/share/example/data.txt"
        '';
      });
    };
}
```

## Direct hook usage

If you already manage derivation attributes yourself, export the setup hook and
include it in `nativeBuildInputs` directly.

```nix
let
  contract = {
    out.files = [ "share/example/data.txt" ];
  };

  contractHook = nix-contract.lib.contractHook {
    inherit pkgs;
    inherit (pkgs) lib;
  } contract;
in
pkgs.stdenv.mkDerivation {
  pname = "example";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    mkdir -p "$out/share/example"
    cp ./data.txt "$out/share/example/data.txt"
  '';

  nativeBuildInputs = [ contractHook ];
  doInstallCheck = true;

  passthru.contract = contract;
}
```

## Contract schema

Contracts are attached to an existing derivation.

Use the output name as the contract key.

```nix
withContract {
  out.files = [ "share/example/data.txt" ];
} drv
```

For multiple outputs, add more output keys.

```nix
withContract {
  out.files = [ "bin/example" ];
  dev.files = [ "include/example.h" ];
} drv
```

Each file path is checked from the root of its output.
