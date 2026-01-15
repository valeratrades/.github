# Generates load_nix job - installs nix + packages once, cached for other jobs
# packages: list of nixpkgs attribute name strings, e.g. [ "wayland" "libGL" "openssl" ]
{ packages ? [] }:
let
  # Always include openssl.out (runtime libs) and openssl.dev (headers)
  # because "openssl" alone resolves to openssl-bin which has no libraries
  allPackages = packages ++ [ "openssl.out" "openssl.dev" ];
  hasPackages = packages != [];
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
        name = "Cache packages";
        run = ''
          # Pre-fetch packages into nix store so they're cached for dependent jobs
          # Use nix-shell which properly sets up env vars like PKG_CONFIG_PATH
          nix-shell -p ${builtins.concatStringsSep " " allPackages} --run "echo packages cached"
        '';
      }
    ];
  };
}
