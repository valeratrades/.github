# Generates load_nix reusable workflow - installs nix + packages once, cached for other jobs
{ packages ? [] }:
let
  hasPackages = packages != [];
  packagePaths = builtins.concatStringsSep " " (map (p: "${p}") packages);
in
if !hasPackages then null else
{
  name = "load_nix";
  on.workflow_call = {};
  permissions.contents = "read";
  jobs.load_nix = {
    runs-on = "ubuntu-latest";
    steps = [
      {
        name = "Install Nix";
        uses = "DeterminateSystems/nix-installer-action@main";
      }
      {
        name = "Setup Nix cache";
        uses = "DeterminateSystems/magic-nix-cache-action@main";
      }
      {
        name = "Install packages";
        run = "nix-env -i ${packagePaths}";
      }
    ];
  };
}
