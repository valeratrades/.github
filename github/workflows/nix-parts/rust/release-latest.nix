# Generates "latest" release workflows - one per platform
# Triggers on push to release branch, creates rolling releases tagged latest-{platform}
# Useful for distributing binaries without semantic versioning
{
  platforms ? [ "debian" "windows" ],
  # Optional cargo flags per platform
  cargoFlags ? {},
  # Optional apt dependencies for debian builds
  aptDeps ? [],
  # Branch that triggers the release
  branch ? "release",
}:
let
  platformConfig = {
    debian = {
      os = "ubuntu-latest";
      binary = "\${{ github.event.repository.name }}";
      artifact_suffix = "";
      tag = "latest-debian";
      release_name = "Debian/Ubuntu Build";
    };
    windows = {
      os = "windows-latest";
      binary = "\${{ github.event.repository.name }}.exe";
      artifact_suffix = ".exe";
      tag = "latest-windows";
      release_name = "Windows Build";
    };
    macos = {
      os = "macos-latest";
      binary = "\${{ github.event.repository.name }}";
      artifact_suffix = "";
      tag = "latest-macos";
      release_name = "macOS Build";
    };
  };

  makeWorkflow = platform:
    let
      cfg = platformConfig.${platform};
      flags = cargoFlags.${platform} or "";
    in {
      standalone = true;
      filename = "release-${platform}.yml";

      name = "${cfg.release_name}";
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
        "build-${platform}" = {
          runs-on = cfg.os;
          steps = [
            { uses = "actions/checkout@v4"; }
            { uses = "dtolnay/rust-toolchain@nightly"; }
          ] ++ (if platform == "debian" && aptDeps != [] then [{
              name = "Install dependencies";
              run = ''
                sudo apt-get update
                sudo apt-get install -y ${builtins.concatStringsSep " " aptDeps}
              '';
            }] else []) ++ [
            {
              name = "Build release binary";
              run = "cargo build --release${if flags != "" then " ${flags}" else ""}";
            }
            {
              name = "Upload artifact";
              uses = "actions/upload-artifact@v4";
              "with" = {
                name = "\${{ github.event.repository.name }}-${platform}";
                path = "target/release/\${{ github.event.repository.name }}${cfg.artifact_suffix}";
              };
            }
            {
              name = "Create Release";
              uses = "softprops/action-gh-release@v2";
              "with" = {
                tag_name = cfg.tag;
                name = cfg.release_name;
                files = "target/release/\${{ github.event.repository.name }}${cfg.artifact_suffix}";
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
  workflows = builtins.listToAttrs (map (p: {
    name = p;
    value = makeWorkflow p;
  }) platforms);
}
