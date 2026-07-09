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
      url = "github:janet-lang/spork/v1.1.1";
      flake = false;
    };

    jurl = {
      url = "github:cosmictoast/jurl/v1.4.3";
      flake = false;
    };

    jdoc = {
      url = "github:sogaiu/jdoc";
      flake = false;
    };

    janet-c = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.41.2/janet.c";
      flake = false;
    };
    janet-h = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.41.2/janet.h";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "armv7l-linux"
      ];

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
        armv7lMuslPkgs = import inputs.nixpkgs {
          inherit system;
          crossSystem = {
            config = "armv7l-unknown-linux-musleabihf";
          };
        };

        jpm =
          if system == "armv7l-linux"
          then
            pkgs.jpm.overrideAttrs (old: {
              postPatch = ''
                substituteInPlace configs/linux_config.janet \
                  --replace 'auto-shebang true' 'auto-shebang false' \
                  --replace /usr/local $out
              '';
              installPhase = ''
                runHook preInstall

                mkdir -p $out/{lib/janet,share/man/man1}

                janet bootstrap.janet configs/linux_config.janet

                # patch default config to use janet's path instead of jpm itself
                substituteInPlace $out/lib/janet/jpm/default-config.janet \
                  --replace-fail $out ${pkgs.janet}

                runHook postInstall
              '';
              meta =
                old.meta
                // {
                  platforms = old.meta.platforms ++ ["armv7l-linux"];
                };
            })
          else pkgs.jpm;

        spork = pkgs.stdenv.mkDerivation {
          pname = "spork";
          version = "1.1.1";
          src = inputs.spork;

          nativeBuildInputs = [
            jpm
            pkgs.janet
          ];

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

        jdoc =
          if inputs.janet2nix.lib ? ${system}
          then
            j2nLib.mkJanetPackage {
              name = "jdoc";
              src = inputs.jdoc;
            }
          else null;

        jurl = pkgs.stdenv.mkDerivation {
          pname = "jurl";
          version = "1.4.3";
          src = inputs.jurl;

          nativeBuildInputs = [
            jpm
            pkgs.janet
          ];
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

        mkSporkFor = targetPkgs:
          targetPkgs.stdenv.mkDerivation {
            pname = "spork";
            version = "1.1.1";
            src = inputs.spork;

            nativeBuildInputs = [
              jpm
              pkgs.janet
            ];

            buildPhase = ''
              runHook preBuild
              mkdir -p cross-bin
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}cc)" cross-bin/cc
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}cc)" cross-bin/c99
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}c++)" cross-bin/c++
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}ar)" cross-bin/ar
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}ranlib)" cross-bin/ranlib
              export PATH="$(pwd)/cross-bin:$PATH"
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

        mkJurlFor = targetPkgs:
          targetPkgs.stdenv.mkDerivation {
            pname = "jurl";
            version = "1.4.3";
            src = inputs.jurl;

            nativeBuildInputs = [
              jpm
              pkgs.janet
              pkgs.pkg-config
            ];
            buildInputs = [targetPkgs.curl];

            postPatch = ''
              substituteInPlace project.janet \
                --replace-fail '["cc" "-xc" "-" "-o/dev/null"' \
                               '["${targetPkgs.stdenv.cc.targetPrefix}cc" "-xc" "-" "-o/dev/null"'
            '';

            buildPhase = ''
              runHook preBuild
              mkdir -p cross-bin
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}cc)" cross-bin/cc
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}cc)" cross-bin/c99
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}c++)" cross-bin/c++
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}ar)" cross-bin/ar
              ln -s "$(command -v ${targetPkgs.stdenv.cc.targetPrefix}ranlib)" cross-bin/ranlib
              export PATH="$(pwd)/cross-bin:$PATH"
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

        mkCrossVpn = {
          targetPkgs,
          staticPkgs,
          pname,
        }: let
          targetSpork = mkSporkFor targetPkgs;
          targetJurl = mkJurlFor targetPkgs;
        in
          targetPkgs.stdenv.mkDerivation {
            inherit pname;
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.pkg-config
            ];
            buildInputs = [
              staticPkgs.curl
            ];

            unpackPhase = ''
              cp ${self'.packages.vpn-c}/vpn.c vpn.c
              cp ${self'.packages.vpn-c}/janet.c janet.c
              cp ${self'.packages.vpn-c}/janet.h janet.h
              cp ${targetSpork}/jpm_tree/lib/spork/json.a spork-json.a
              cp ${targetJurl}/jpm_tree/lib/jurl/native.a jurl-native.a
              cp -r $src/completions completions
            '';

            buildPhase = ''
              runHook preBuild
              $CC -static -o vpn vpn.c janet.c spork-json.a jurl-native.a -I. \
                $(pkg-config --cflags --libs --static libcurl) -O2
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm755 vpn $out/bin/vpn
              install -Dm644 completions/vpn.bash $out/share/bash-completion/completions/vpn
              install -Dm644 completions/_vpn $out/share/zsh/site-functions/_vpn
              runHook postInstall
            '';

            meta = {
              description = "VPN util cross-compiled for ${targetPkgs.stdenv.hostPlatform.system}";
              platforms = [targetPkgs.stdenv.hostPlatform.system];
            };
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
            shellHook =
              if jdoc != null
              then ''
                export JANET_PATH="${jdoc}/jpm_tree/lib:$JANET_PATH"
                export PATH="${jdoc}/jpm_tree/bin:$PATH"
              ''
              else "";
          };
        };

        packages =
          {
            default = pkgs.stdenv.mkDerivation {
              pname = name;
              version = "0.1.6";
              src = ./.;

              nativeBuildInputs = [
                jpm
                pkgs.janet
              ];

              buildInputs = [
                jpm
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
                install -Dm644 completions/vpn.bash $out/share/bash-completion/completions/vpn
                install -Dm644 completions/_vpn $out/share/zsh/site-functions/_vpn
                runHook postInstall
              '';

              meta = {
                description = "vpn util built with Janet (jpm quickbin)";
                platforms = pkgs.lib.platforms.unix;
              };
            };

            vpn-c = pkgs.stdenv.mkDerivation {
              pname = "vpn-c";
              version = "0.1.4";
              src = ./.;

              nativeBuildInputs = [
                jpm
                pkgs.janet
              ];
              buildInputs = [
                jpm
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
              src = ./.;

              buildInputs = [
                pkgs.curl
              ];

              unpackPhase = ''
                cp ${self'.packages.vpn-c}/vpn.c vpn.c
                cp ${self'.packages.vpn-c}/janet.c janet.c
                cp ${self'.packages.vpn-c}/janet.h janet.h
                cp ${spork}/jpm_tree/lib/spork/json.a spork-json.a
                cp ${jurl}/jpm_tree/lib/jurl/native.a jurl-native.a
                cp -r $src/completions completions
              '';

              buildPhase = ''
                runHook preBuild
                $CC -o vpn vpn.c janet.c spork-json.a jurl-native.a -I. -lm -ldl -lcurl -O2
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall
                install -Dm755 vpn $out/bin/vpn
                install -Dm644 completions/vpn.bash $out/share/bash-completion/completions/vpn
                install -Dm644 completions/_vpn $out/share/zsh/site-functions/_vpn
                runHook postInstall
              '';

              meta = {
                description = "VPN util compiled from C source";
                platforms = pkgs.lib.platforms.unix;
              };
            };
          }
          // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            vpn-aarch64 = mkCrossVpn {
              pname = "vpn-aarch64";
              targetPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl;
              staticPkgs = pkgs.pkgsCross.aarch64-multiplatform.pkgsStatic;
            };

            vpn-armv7l = mkCrossVpn {
              pname = "vpn-armv7l";
              targetPkgs = armv7lMuslPkgs;
              staticPkgs = armv7lMuslPkgs.pkgsStatic;
            };
          };

        apps = {
          default = {
            type = "app";
            program = "${self'.packages.default}/bin/vpn";
          };
        };
      };

      flake = {
        defaultPackage = {
          armv7l-linux = self.packages.armv7l-linux.default;
        };
      };
    };
}
