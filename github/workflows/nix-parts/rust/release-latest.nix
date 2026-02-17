# Generates "latest" release workflows - one per target
# Triggers on push to release branch, creates rolling releases tagged latest-{target-short}
# Uses `nix build` for proper reproducible builds with correct linking
{
  # Set to true to use defaults, or customize individual fields
  # Accepts both `default` and `defaults` as aliases
  defaults ? false,
  default ? defaults,
  targets ? [
    "x86_64-linux"
    "aarch64-linux"
  ],
  # Install config from parent - no longer used for release (nix build handles deps)
  installConfig ? {},
  # Legacy params (deprecated, ignored)
  install ? {},
  aptDeps ? [],
  cargoFlags ? {},
  # Branch that triggers the release
  branch ? "release",
}:
let
  nixSystemToGhaOs = system:
    if builtins.match ".*-linux" system != null then "ubuntu-latest"
    else if builtins.match ".*-darwin" system != null then "macos-latest"
    else "ubuntu-latest";

  nixSystemToShortName = system:
    if system == "x86_64-linux" then "linux-x86_64"
    else if system == "aarch64-linux" then "linux-aarch64"
    else if system == "x86_64-darwin" then "macos-x86_64"
    else if system == "aarch64-darwin" then "macos-aarch64"
    else builtins.replaceStrings ["-"] ["_"] system;

  isLinux = system: builtins.match ".*-linux" system != null;

  makeWorkflow = system:
    let
      os = nixSystemToGhaOs system;
      shortName = nixSystemToShortName system;
      nixPkg = if isLinux system then ".#packages.${system}.static" else ".#packages.${system}.default";
    in {
      standalone = true;
      filename = "release-${shortName}.yml";

      name = "Release ${shortName}";
      on = {
        push = {
          branches = [ branch ];
        };
        workflow_dispatch = { };
      };
      permissions = {
        contents = "write";
      };
      env = {
        CARGO_INCREMENTAL = "0";
        CARGO_NET_RETRY = "10";
        RUSTUP_MAX_RETRIES = "10";
      };
      jobs = {
        "build" = {
          runs-on = os;
          steps = [
            { uses = "actions/checkout@v4"; }
            {
              name = "Install Nix";
              uses = "DeterminateSystems/nix-installer-action@main";
            }
            {
              name = "Setup Nix cache";
              uses = "DeterminateSystems/magic-nix-cache-action@main";
            }
            {
              name = "Build release binary";
              run = "nix build ${nixPkg} --no-link --print-out-paths | tee /tmp/nix-out";
            }
            {
              name = "Copy binary";
              run = ''
                PNAME="''${{ github.event.repository.name }}"
                OUT=$(cat /tmp/nix-out)
                cp "''${OUT}/bin/''${PNAME}" ./
              '';
            }
            {
              name = "Upload artifact";
              uses = "actions/upload-artifact@v4";
              "with" = {
                name = "\${{ github.event.repository.name }}-${shortName}";
                path = "\${{ github.event.repository.name }}";
              };
            }
            {
              name = "Create Release";
              uses = "softprops/action-gh-release@v2";
              "with" = {
                tag_name = "latest-${shortName}";
                name = "Latest ${shortName}";
                files = "\${{ github.event.repository.name }}";
                prerelease = true;
                make_latest = false;
              };
              env = {
                GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
              };
            }
          ];
        };
      };
    };
in
{
  workflows = builtins.listToAttrs (map (t: {
    name = nixSystemToShortName t;
    value = makeWorkflow t;
  }) targets);
}
