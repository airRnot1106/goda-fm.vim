{
  description = "Jump to a fuzzy matched word in Vim and Neovim on goda.vim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    goda-nix = {
      url = "github:airRnot1106/goda.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, goda-nix, ... }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ] (system: f nixpkgs.legacyPackages.${system});

      build = pkgs: rec {
        plugin = goda-nix.lib.buildGodaPlugin pkgs {
          src = ./.;
          version = "0.1.0";
          vendorHash = "sha256-n6A5Ci+4zJaF9MFmnbd+2xMDaGzCmwbHoOOcvlhLmag=";
        };

        dictionary = pkgs.fetchurl {
          url = "https://github.com/oguna/migemo-compact-dict-latest/releases/download/v0.2/migemo-compact-dict";
          hash = "sha256-+jrCQLM1iSIvzUCRDe0sFpc3TgGvFNwrtd32g6oumho=";
        };

        goTest =
          name: nativeBuildInputs: command:
          plugin.binary.overrideAttrs (prev: {
            name = "goda-fm-${name}";
            doCheck = true;
            nativeBuildInputs = prev.nativeBuildInputs ++ nativeBuildInputs;
            checkPhase = ''
              runHook preCheck
              export HOME=$TMPDIR
              export GODA_KS_TEST_DICT=${dictionary}
              ${command}
              runHook postCheck
            '';
            installPhase = "touch $out";
          });
      };
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          inherit (build pkgs) plugin;
        in
        {
          default = plugin;
          vim-plugin = plugin;
          goda-fm = plugin.binary;
          goda-vim = plugin.godaVim;
        }
      );

      checks = forAllSystems (
        pkgs:
        let
          inherit (build pkgs) goTest;
        in
        {
          unit = goTest "unit" [ ] "go test ./internal/...";
          e2e = goTest "e2e" [
            pkgs.vim
            pkgs.neovim
          ] "GODA_FM_E2E_STRICT=1 go test -v -count=1 ./e2e";
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (build pkgs).plugin.binary.go
            pkgs.vim
            pkgs.neovim
          ];
        };
      });
    };
}
