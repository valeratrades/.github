# Generates per-target release workflows for cargo-binstall compatible binary distribution
# Each target gets its own workflow file (release-{shortName}.yml)
# Supports tag trigger (v* tags) and/or release_branch trigger (push to branch)
#
# Every run uploads to BOTH:
#   1. A rolling `latest-{shortName}` pre-release (always)
#   2. The versioned semver release (tag from push, or largest existing v* tag)
{
  # Set to true to use defaults, or customize individual fields
  # Accepts both `default` and `defaults` as aliases
  defaults ? false,
  default ? defaults,
  targets ? [
    "x86_64-unknown-linux-gnu"
    "x86_64-apple-darwin"
    "aarch64-apple-darwin"
  ],
  # Optional cargo flags per target (e.g., for --no-default-features on windows)
  cargoFlags ? {},
  # Optional apt dependencies for linux builds
  aptDeps ? [],
  # Trigger config: which triggers to generate for
  triggers ? { tag = true; },
  # Branch for release_branch trigger
  branch ? "release",
  # Legacy params (ignored, kept for backwards compat)
  installConfig ? {},
  install ? {},
}:
let
  targetToOs = target:
    if builtins.match ".*-linux-.*" target != null then "ubuntu-latest"
    else if builtins.match ".*-apple-.*" target != null then "macos-latest"
    else if builtins.match ".*-windows-.*" target != null then "windows-latest"
    else "ubuntu-latest";

  targetToShortName = target:
    if target == "x86_64-unknown-linux-gnu" then "linux-x86_64"
    else if target == "aarch64-unknown-linux-gnu" then "linux-aarch64"
    else if target == "x86_64-apple-darwin" then "macos-x86_64"
    else if target == "aarch64-apple-darwin" then "macos-aarch64"
    else if target == "x86_64-pc-windows-msvc" then "windows-x86_64"
    else builtins.replaceStrings ["-unknown" "-gnu" "-msvc"] ["" "" ""] target;

  isWindows = target: builtins.match ".*-windows-.*" target != null;
  isLinux = target: builtins.match ".*-linux-.*" target != null;

  hasTag = triggers.tag or false;
  hasBranch = triggers.branch or false;

  triggerOn =
    let
      tagPart = if hasTag then { push.tags = [ "v[0-9]+.*" ]; } else {};
      branchPart = if hasBranch then { push.branches = [ branch ]; } else {};
      pushPart = if hasTag && hasBranch then {
        push = { tags = [ "v[0-9]+.*" ]; branches = [ branch ]; };
      } else tagPart // branchPart;
    in pushPart // { workflow_dispatch = {}; };

  makeWorkflow = target:
    let
      os = targetToOs target;
      shortName = targetToShortName target;
      flags = cargoFlags.${target} or "";
      binarySuffix = if isWindows target then ".exe" else "";
      archiveName = if isWindows target
        then "\${{ github.event.repository.name }}-${target}.zip"
        else "\${{ github.event.repository.name }}-${target}.tar.gz";
    in {
      standalone = true;

      name = "Release ${shortName}";
      on = triggerOn;
      permissions = {
        contents = "write";
      };
      env = {
        CARGO_INCREMENTAL = "0";
        CARGO_NET_RETRY = "10";
        RUSTUP_MAX_RETRIES = "10";
      };
      jobs.build = {
        runs-on = os;
        steps = [
          { uses = "actions/checkout@v4"; }
          {
            name = "Fetch tags";
            run = "git fetch --tags --no-recurse-submodules";
          }
          {
            uses = "dtolnay/rust-toolchain@nightly";
            "with" = {
              targets = target;
            };
          }
        ] ++ (if isLinux target then [{
            name = "Install mold";
            uses = "rui314/setup-mold@v1";
          }] else []) ++ (if isLinux target && aptDeps != [] then [{
            name = "Install dependencies";
            run = ''
              sudo apt-get update
              sudo apt-get install -y ${builtins.concatStringsSep " " aptDeps}
            '';
          }] else []) ++ [
          (if isWindows target then {
            name = "Remove .cargo/config.toml";
            run = "Remove-Item -Force -ErrorAction SilentlyContinue .cargo/config.toml, .cargo/config";
            shell = "pwsh";
          } else {
            name = "Remove .cargo/config.toml";
            run = "rm -f .cargo/config.toml .cargo/config";
          })
          {
            name = "Build release binary";
            run = "cargo build --release --target ${target}${if flags != "" then " ${flags}" else ""}";
          }
        ]
        # Package step: tar.gz for unix, zip for windows
        ++ (if isWindows target then [{
          name = "Package binary";
          run = ''
            cd target/${target}/release
            ''$PNAME = ''$env:GITHUB_REPOSITORY.Split('/')[-1]
            Compress-Archive -Path "''$PNAME.exe" -DestinationPath "../../../''$PNAME-${target}.zip"
          '';
          shell = "pwsh";
        }] else [{
          name = "Package binary";
          run = ''
            cd target/${target}/release
            PNAME="''${GITHUB_REPOSITORY##*/}"
            tar -czvf ../../../''${PNAME}-${target}.tar.gz ''$PNAME
          '';
        }])
        ++ [
          # Resolve the semver tag to attach to.
          # If triggered by a tag push, use that tag.
          # Otherwise, find the largest existing v* tag.
          # If no v* tags exist, skip the versioned release.
          {
            name = "Resolve version tag";
            id = "version";
            shell = "bash";
            run = ''
              if [[ "''${{ github.ref_type }}" == "tag" ]]; then
                echo "tag=''${{ github.ref_name }}" >> "''$GITHUB_OUTPUT"
              else
                LATEST=$(git tag -l 'v[0-9]*' --sort=-v:refname | head -1)
                if [[ -n "''$LATEST" ]]; then
                  echo "tag=''$LATEST" >> "''$GITHUB_OUTPUT"
                else
                  echo "::notice::No existing v* tags found, skipping versioned release"
                  echo "tag=" >> "''$GITHUB_OUTPUT"
                fi
              fi
            '';
          }
          # Always upload to rolling latest pre-release
          {
            name = "Release (latest)";
            uses = "softprops/action-gh-release@v2";
            "with" = {
              tag_name = "latest-${shortName}";
              name = "Latest ${shortName}";
              files = archiveName;
              prerelease = true;
              make_latest = false;
            };
            env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
          }
          # Also upload to the versioned release (if a version tag exists)
          {
            name = "Release (versioned)";
            "if" = "steps.version.outputs.tag != ''";
            uses = "softprops/action-gh-release@v2";
            "with" = {
              tag_name = "\${{ steps.version.outputs.tag }}";
              files = archiveName;
            };
            env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
          }
        ];
      };
    };
in
{
  workflows = builtins.listToAttrs (map (t: {
    name = targetToShortName t;
    value = makeWorkflow t;
  }) targets);
}
