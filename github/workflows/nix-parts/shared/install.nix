# Generate install steps from install config
# Supports:
#   - packages: list of nix packages (e.g., with pkgs; [ wayland libxkbcommon ])
#   - apt: list of apt package names (deprecated)
#
# Returns a list of step attrsets to insert after checkout
{ packages ? [], apt ? [], linuxOnly ? true }:
let
  # Nix-based installation - packages are actual derivations, get their /nix/store paths
  nixSteps = if packages != [] then
    let
      # Create a buildEnv that combines all packages
      pkgs = builtins.head packages; # Get pkgs from the first package's context
      env = (import <nixpkgs> {}).buildEnv {
        name = "ci-deps";
        paths = packages;
      };
    in [
    {
      name = "Install Nix";
      uses = "DeterminateSystems/nix-installer-action@main";
    }
    {
      name = "Setup Nix cache";
      uses = "DeterminateSystems/magic-nix-cache-action@main";
    }
    {
      name = "Install dependencies via Nix";
      run = ''
        nix-env -i ${builtins.concatStringsSep " " (map (p: "${p}") packages)}
      '';
    }
  ] else [];

  #DEPRECATE: apt-based installation
  _ = if apt != [] then builtins.trace "WARNING: install.apt is deprecated, use install.packages instead" null else null;
  baseAptStep = {
    name = "Install dependencies (apt)";
    run = ''
      sudo apt-get update
      sudo apt-get install -y ${builtins.concatStringsSep " " apt}
    '';
  };
  aptSteps = if apt != [] then [
    (if linuxOnly then baseAptStep // { "if" = "runner.os == 'Linux'"; } else baseAptStep)
  ] else [];
in
nixSteps ++ aptSteps
