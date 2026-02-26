# Generates per-target release workflows for cargo-binstall compatible binary distribution
# Each target gets its own workflow file (release-{shortName}.yml)
# Supports tag trigger (v* tags) and/or release_branch trigger (push to branch)
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
      # Merge push triggers
      pushPart = if hasTag && hasBranch then {
        push = { tags = [ "v[0-9]+.*" ]; branches = [ branch ]; };
      } else tagPart // branchPart;
    in pushPart // { workflow_dispatch = {}; };

  # For tag trigger: resolve the tag name (from tag push or from Cargo.toml on workflow_dispatch)
  # For branch trigger: use rolling "latest-{shortName}" tag
  makeReleaseStep = target:
    let
      shortName = targetToShortName target;
      binarySuffix = if isWindows target then ".exe" else "";
      archiveName = if isWindows target
        then "\${{ github.event.repository.name }}-${target}.zip"
        else "\${{ github.event.repository.name }}-${target}.tar.gz";
    in
    if hasTag && !hasBranch then {
      # Pure tag trigger: version-tagged release
      name = "Create Release";
      uses = "softprops/action-gh-release@v2";
      "with" = {
        tag_name = "\${{ steps.tag.outputs.tag }}";
        files = archiveName;
      };
      env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
    }
    else if !hasTag && hasBranch then {
      # Pure branch trigger: rolling latest release
      name = "Create Release";
      uses = "softprops/action-gh-release@v2";
      "with" = {
        tag_name = "latest-${shortName}";
        name = "Latest ${shortName}";
        files = "target/${target}/release/\${{ github.event.repository.name }}${binarySuffix}";
        prerelease = true;
        make_latest = false;
      };
      env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
    }
    else {
      # Both triggers: decide at runtime
      name = "Create Release";
      uses = "softprops/action-gh-release@v2";
      "with" = {
        tag_name = "\${{ steps.release-meta.outputs.tag }}";
        name = "\${{ steps.release-meta.outputs.name }}";
        files = "\${{ steps.release-meta.outputs.files }}";
        prerelease = "\${{ steps.release-meta.outputs.prerelease }}";
        make_latest = "\${{ steps.release-meta.outputs.make_latest }}";
      };
      env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
    };

  makeWorkflow = target:
    let
      os = targetToOs target;
      shortName = targetToShortName target;
      flags = cargoFlags.${target} or "";
      binarySuffix = if isWindows target then ".exe" else "";
      binaryPath = "target/${target}/release/\${{ github.event.repository.name }}${binarySuffix}";
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
        # Package step: tar.gz for unix, zip for windows (needed for binstall compat)
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
        # Tag resolution step (only for tag trigger or dual trigger)
        # Always use bash shell since these use bash syntax (windows defaults to pwsh)
        ++ (if hasTag && !hasBranch then [{
          name = "Resolve release tag";
          id = "tag";
          shell = "bash";
          run = ''
            if [[ "''${{ github.ref_type }}" == "tag" ]]; then
              echo "tag=''${{ github.ref_name }}" >> "''$GITHUB_OUTPUT"
            else
              VERSION=$(sed -n '/^\[package\]/,/^\[/{s/^version *= *"\(.*\)"/\1/p}' Cargo.toml | head -1)
              if [[ -z "''$VERSION" ]]; then
                echo "::error::No version found in Cargo.toml [package] section"
                exit 1
              fi
              echo "tag=v''$VERSION" >> "''$GITHUB_OUTPUT"
            fi
          '';
        }] else if hasTag && hasBranch then [{
          name = "Resolve release metadata";
          id = "release-meta";
          shell = "bash";
          run = ''
            PNAME="''${GITHUB_REPOSITORY##*/}"
            if [[ "''${{ github.ref_type }}" == "tag" ]]; then
              echo "tag=''${{ github.ref_name }}" >> "''$GITHUB_OUTPUT"
              echo "name=''${{ github.ref_name }}" >> "''$GITHUB_OUTPUT"
              echo "files=${archiveName}" >> "''$GITHUB_OUTPUT"
              echo "prerelease=false" >> "''$GITHUB_OUTPUT"
              echo "make_latest=true" >> "''$GITHUB_OUTPUT"
            else
              echo "tag=latest-${shortName}" >> "''$GITHUB_OUTPUT"
              echo "name=Latest ${shortName}" >> "''$GITHUB_OUTPUT"
              echo "files=${binaryPath}" >> "''$GITHUB_OUTPUT"
              echo "prerelease=true" >> "''$GITHUB_OUTPUT"
              echo "make_latest=false" >> "''$GITHUB_OUTPUT"
            fi
          '';
        }] else [])
        ++ [ (makeReleaseStep target) ];
      };
    };
in
{
  workflows = builtins.listToAttrs (map (t: {
    name = targetToShortName t;
    value = makeWorkflow t;
  }) targets);
}
