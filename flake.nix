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

    jurl = {
      url = "github:cosmictoast/jurl/v1.4.3";
      flake = false;
    };

    janet-c = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.40.1/janet.c";
      flake = false;
    };
    janet-h = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.40.1/janet.h";
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

        jurl = pkgs.stdenv.mkDerivation {
          pname = "jurl";
          version = "1.4.3";
          src = inputs.jurl;

          nativeBuildInputs = [pkgs.jpm pkgs.janet];
          buildInputs = [pkgs.curl];

          buildPhase = ''
            runHook preBuild
            jpm build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/jpm_tree
            export JANET_TREE=$out/jpm_tree
            jpm install
            runHook postInstall
          '';
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
              pkgs.curl
            ];

            buildPhase = ''
              runHook preBuild
              # Create a combined module directory
              mkdir -p combined_modules
              cp -r ${spork}/jpm_tree/lib/* combined_modules/ || true
              cp -r ${jurl}/jpm_tree/lib/* combined_modules/ || true
              export JANET_PATH="$(pwd)/combined_modules"
              jpm build --libpath=${pkgs.janet}/lib --modpath=$(pwd)/combined_modules
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
              pkgs.curl
            ];

            buildPhase = ''
              runHook preBuild
              # Create a combined module directory
              mkdir -p combined_modules
              cp -r ${spork}/jpm_tree/lib/* combined_modules/ || true
              cp -r ${jurl}/jpm_tree/lib/* combined_modules/ || true
              export JANET_PATH="$(pwd)/combined_modules"
              jpm build --libpath=${pkgs.janet}/lib --modpath=$(pwd)/combined_modules
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

          vpn-static = pkgs.stdenv.mkDerivation {
            pname = "vpn-static";
            version = "0.1.0";
            src = self'.packages.vpn-c;

            buildInputs = [
              pkgs.curl
            ];

            unpackPhase = ''
              cp ${self'.packages.vpn-c}/vpn.c vpn.c
              cp ${self'.packages.vpn-c}/janet.c janet.c
              cp ${self'.packages.vpn-c}/janet.h janet.h
              cp ${spork}/jpm_tree/lib/spork/json.a spork-json.a
              cp ${jurl}/jpm_tree/lib/jurl/native.a jurl-native.a
            '';

            buildPhase = ''
              runHook preBuild
              $CC -o vpn vpn.c janet.c spork-json.a jurl-native.a -I. -lm -ldl -lcurl -O2
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm755 vpn $out/bin/vpn
              runHook postInstall
            '';

            meta = {
              description = "VPN util compiled from C source";
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
