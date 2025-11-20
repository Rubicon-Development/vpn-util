{
  description = "vpn-util: Janet build via flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    janet2nix.url = "github:alan-strohm/janet2nix";

    janet-lsp-src = {
      url = "github:Blue-Berry/janet-lsp.nix";
      flake = false;
    };

    spork = {
      url = "github:janet-lang/spork";
      flake = false;
    };

    janet-c = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.39.1/janet.c";
      flake = false;
    };
    janet-h = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.39.1/janet.h";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        j2nLib = inputs.janet2nix.lib.${system};
        janet-lsp = pkgs.callPackage inputs.janet-lsp-src {};
        inherit (pkgs) mkShell;
        name = "vpn";

        spork = j2nLib.mkJanetPackage {
          name = "spork";
          src = inputs.spork;
        };
      in {
        devShells = {
          default = mkShell {
            inputsFrom = [self'.packages.default];
            buildInputs = with pkgs; [
              janet
              jpm
              janet-lsp
            ];
          };
        };

        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = name;
            version = "0.1.3";
            src = ./.;

            nativeBuildInputs = [
              pkgs.jpm
              pkgs.janet
            ];

            buildInputs = [
              pkgs.jpm
              pkgs.janet
            ];

            buildPhase = ''
              runHook preBuild
              export JANET_PATH="${spork}/jpm_tree/lib"
              export JANET_MODPATH="${spork}/jpm_tree/lib"
              jpm build --libpath=${pkgs.janet}/lib --modpath=${spork}/jpm_tree/lib
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm755 build/vpn $out/bin/vpn
              runHook postInstall
            '';

            meta = {
              description = "vpn util built with Janet (jpm quickbin)";
              platforms = pkgs.lib.platforms.unix;
            };
          };

          vpn-c = pkgs.stdenv.mkDerivation {
            pname = "vpn-c";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.jpm
              pkgs.janet
            ];
            buildInputs = [
              pkgs.jpm
              pkgs.janet
            ];

            buildPhase = ''
              runHook preBuild
              jpm build --libpath=${pkgs.janet}/lib
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm644 build/vpn.c $out/vpn.c
              install -Dm644 ${inputs.janet-c} $out/janet.c
              install -Dm644 ${inputs.janet-h} $out/janet.h
              runHook postInstall
            '';

            meta = {
              description = "Generated C source for vpn util";
              platforms = pkgs.lib.platforms.unix;
            };
          };
        };

        apps = {
          default = {
            type = "app";
            program = "${self'.packages.default}/bin/vpn";
          };
        };
      };
    };
}
