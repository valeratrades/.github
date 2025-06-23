#TODO: move the GHA generator up to the root level
{
  description = ''
# Nix parts collection

Collection of reusable Nix components.
See individual component descriptions in their respective directories.'';

  outputs = { self, nixpkgs }: let
    parts = {
      files = (import ./files { inherit nixpkgs; }).description;
      hooks = (import ./hooks { inherit nixpkgs; }).description;
      readme-fw = (import ./readme_fw { inherit nixpkgs; }).description;
      workflows = (import ./.github/workflows/nix-parts { inherit nixpkgs; }).description;
    };
  in {
    description = ''
## Files
${parts.files}

## Hooks
${parts.hooks}

## Readme Framework
${parts.readme-fw}

## Workflows
${parts.workflows}
'';

    files = import ./files;
    hooks = import ./hooks;
    readme-fw = import ./readme_fw;
		ci = import ./.github/workflows/nix-parts;
		utils = import ./utils;
  };
}
