# Generate install steps from install config: { apt = [ "pkg1" ... ]; }
# Returns a list of step attrsets to insert after checkout
# Set linuxOnly = false if targeting a specific Linux platform (no runtime check needed)
{ apt ? [], linuxOnly ? true }:
let
  baseStep = {
    name = "Install dependencies";
    run = ''
      sudo apt-get update
      sudo apt-get install -y ${builtins.concatStringsSep " " apt}
    '';
  };
  aptStep = if apt != [] then [
    (if linuxOnly then baseStep // { "if" = "runner.os == 'Linux'"; } else baseStep)
  ] else [];
in
aptStep
