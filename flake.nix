{
  description = ''
# Nix parts collection

Collection of reusable Nix components.
See individual component descriptions in their respective directories.'';

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Version constants for bundled packages - update these when bumping
      traceyVersion = "1.0.0";
      codestyleVersion = "0.1.1";

      parts = {
        files = (import ./files).description;
        github = (import ./github { inherit nixpkgs; }).description;
        rs = (import ./rs { inherit nixpkgs; }).description;
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        utils = import ./utils;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ curl ];
          shellHook = ''
            ${utils.checkCrateVersion { name = "tracey"; currentVersion = traceyVersion; }}
            ${utils.checkCrateVersion { name = "codestyle"; currentVersion = codestyleVersion; }}
          '';
        };
      }
    ) // {
      description = ''
## Files
${parts.files}

## GitHub
${parts.github}

## Rust
${parts.rs}

## Readme Framework
Generates README.md from .readme_assets/ directory structure.
'';

      files = import ./files;
      github = import ./github;
      rs = import ./rs;
      readme-fw = import ./readme_fw;
      utils = import ./utils;

      # Backward compatibility aliases
      hooks = {
        description = "DEPRECATED: Use github module instead";
        appendCustom = ./github/append_custom.rs;
        treefmt = import ./files/treefmt.nix;
        preCommit = import ./github/pre_commit.nix;
      };
      workflows = import ./github/workflows/nix-parts;
      ci = import ./github;
    };
}
