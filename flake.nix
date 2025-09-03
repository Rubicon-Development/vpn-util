{
  description = "vpn-util: Janet build via flakes";

  inputs =  {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    janet-c = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.39.1/janet.c";
      flake = false;
    };
    janet-h = {
      url = "https://github.com/janet-lang/janet/releases/download/v1.39.1/janet.h";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, janet-c, janet-h }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "vpn";
            version = "0.1.0";
            src = ./.;

            # jpm comes with janet in nixpkgs
            nativeBuildInputs = [ pkgs.jpm pkgs.janet ];
            buildInputs = [ pkgs.jpm pkgs.janet ];

            # jpm may invoke ld directly; avoid GCC-style -Wl flags.
            # We rely on wrapping to provide runtime lib path instead of rpath.

            buildPhase = ''
              runHook preBuild
              jpm build --libpath=${pkgs.janet}/lib
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm755 build/vpn $out/bin/vpn
              runHook postInstall
            '';

            meta = {
              description = "vpn util built with Janet (jpm quickbin)";
              platforms = lib.platforms.unix;
            };
          };

          vpn-c = pkgs.stdenv.mkDerivation {
            pname = "vpn-c";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.jpm pkgs.janet ];
            buildInputs = [ pkgs.jpm pkgs.janet ];

            buildPhase = ''
              runHook preBuild
              jpm build --libpath=${pkgs.janet}/lib
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm644 build/vpn.c $out/vpn.c
              install -Dm644 ${janet-c} $out/janet.c
              install -Dm644 ${janet-h} $out/janet.h
              runHook postInstall
            '';

            meta = {
              description = "Generated C source for vpn util";
              platforms = lib.platforms.unix;
            };
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/vpn";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.janet
          ];
        };
      });
}
