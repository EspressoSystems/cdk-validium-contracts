{
  description =
    "cdk-validium-contracts, with go, rust, and nodejs development environment";

  nixConfig = {
    extra-substituters = [ "https://espresso-systems-private.cachix.org" ];
    extra-trusted-public-keys = [
      "espresso-systems-private.cachix.org-1:LHYk03zKQCeZ4dvg3NctyCq88e44oBZVug5LpYKjPRI="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  inputs.foundry.url =
    "github:shazow/foundry.nix/monthly"; # Use monthly branch for permanent releases
  inputs.solc-bin.url = "github:EspressoSystems/nix-solc-bin";

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , flake-compat
    , pre-commit-hooks
    , foundry
    , solc-bin
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [ foundry.overlay solc-bin.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };
    in
    with pkgs; {
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            githooks = {
              enable = true;
              description = "original githook";
              entry = "./.githooks/pre-commit";
            };
            npm-lint = {
              enable = true;
              description = "Run npm lint";
              entry = "npm run lint";
            };
          };
        };
      };

      devShells.default =
        let
          # nixWithFlakes allows pre v2.4 nix installations to use
          # flake commands (like `nix flake update`)
          nixWithFlakes = pkgs.writeShellScriptBin "nix" ''
            exec ${pkgs.nixFlakes}/bin/nix --experimental-features "nix-command flakes" "$@"
          '';
          solc = pkgs.solc-bin.latest;
        in
        mkShell {
          buildInputs = [
            git
            nixWithFlakes
            entr

            # cdk-validium-contracts
            nodejs

            # Ethereum contracts, solidity, ...
            foundry-bin
            solc
          ] ++ lib.optionals stdenv.isDarwin
            [ darwin.apple_sdk.frameworks.SystemConfiguration ];
          shellHook = ''
            npm i
          '' + self.checks.${system}.pre-commit-check.shellHook;
          FOUNDRY_SOLC = "${solc}/bin/solc";
        };
    });
}
