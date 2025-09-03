{
  description = "vpn-util: Janet build via flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
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
