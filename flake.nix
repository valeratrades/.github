{
  description = ''
# Nix parts collection

Collection of reusable Nix components.
See individual component descriptions in their respective directories.'';

  outputs = { self, nixpkgs }: let
    parts = {
      files = (import ./files).description;
      github = (import ./github { inherit nixpkgs; }).description;
      rs = (import ./rs { inherit nixpkgs; }).description;
    };
  in {
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
