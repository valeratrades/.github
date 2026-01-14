# Generate install steps for jobs that depend on load_nix workflow
# These steps restore the nix cache populated by load_nix
# Also supports legacy apt (deprecated)
# packages: list of nixpkgs attribute name strings
{ packages ? [], apt ? [], linuxOnly ? true }:
let
  # Nix restore steps - restore from cache, then make packages available
  nixSteps = if packages != [] then [
    {
      name = "Install Nix";
      uses = "DeterminateSystems/nix-installer-action@main";
    }
    {
      name = "Restore Nix cache";
      uses = "DeterminateSystems/magic-nix-cache-action@main";
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
