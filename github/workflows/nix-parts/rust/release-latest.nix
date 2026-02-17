# Generates "latest" release workflows - one per target
# Triggers on push to release branch, creates rolling releases tagged latest-{target-short}
# Useful for distributing binaries without semantic versioning
{
  # Set to true to use defaults, or customize individual fields
  # Accepts both `default` and `defaults` as aliases
  defaults ? false,
  default ? defaults,
  targets ? [
    "x86_64-unknown-linux-gnu"
    "aarch64-unknown-linux-gnu"
  ],
  # Optional cargo flags per target
  cargoFlags ? {},
  # Install config from parent (top-level or per-section): { packages = [...]; apt = [...]; debug = bool; }
  installConfig ? {},
  # Legacy params (deprecated)
  install ? {},
  aptDeps ? [],
  # Branch that triggers the release
  branch ? "release",
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

  # Merge all install sources: installConfig (from parent) > install > aptDeps (legacy)
  effectivePackages = installConfig.packages or (install.packages or []);
  effectiveApt = (installConfig.apt or (install.apt or [])) ++ aptDeps;
  effectiveDebug = installConfig.debug or (install.debug or false);
  _ = if aptDeps != [] then builtins.trace "WARNING: releaseLatest.aptDeps is deprecated, use install.packages instead" null else null;

  hasNixPackages = effectivePackages != [];

  # Nix-shell wrapping for run steps
  allPackages = effectivePackages ++ [ "openssl.out" "openssl.dev" ];
  pkgList = builtins.concatStringsSep " " allPackages;
  ldLibPathSetup = builtins.concatStringsSep "" (map (pkg:
    "export LD_LIBRARY_PATH=\\\"\\$(nix-build '<nixpkgs>' -A ${pkg} --no-out-link)/lib\\\${LD_LIBRARY_PATH:+:}\\$LD_LIBRARY_PATH\\\" && "
  ) allPackages);
  wrapRun = run:
    if !hasNixPackages then run
    else if builtins.substring 0 4 run == "nix " then run
    else if builtins.substring 0 9 run == "nix-shell" then run
    else if builtins.substring 0 5 run == "echo " then run
    else "nix-shell -p ${pkgList} --command \"${ldLibPathSetup}${builtins.replaceStrings ["\"" "$"] ["\\\"" "\\$"] run}\"";
  wrapStep = step:
    if step ? run then step // { run = wrapRun step.run; }
    else step;

  makeWorkflow = target:
    let
      os = targetToOs target;
      shortName = targetToShortName target;
      flags = cargoFlags.${target} or "";
      binarySuffix = if isWindows target then ".exe" else "";
      installSteps = if isLinux target
        then import ../shared/install.nix {
          packages = effectivePackages;
          apt = effectiveApt;
          debug = effectiveDebug;
          linuxOnly = false;
        }
        else [];
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
              uses = "dtolnay/rust-toolchain@nightly";
              "with" = {
                targets = target;
              };
            }
          ] ++ (if isLinux target then [{
              name = "Install mold";
              uses = "rui314/setup-mold@v1";
            }] else []) ++ installSteps ++ [
            (wrapStep {
              name = "Build release binary";
              run = "cargo build --release --target ${target}${if flags != "" then " ${flags}" else ""}";
            })
          ] ++ [
            {
              name = "Upload artifact";
              uses = "actions/upload-artifact@v4";
              "with" = {
                name = "\${{ github.event.repository.name }}-${shortName}";
                path = "target/${target}/release/\${{ github.event.repository.name }}${binarySuffix}";
              };
            }
            {
              name = "Create Release";
              uses = "softprops/action-gh-release@v2";
              "with" = {
                tag_name = "latest-${shortName}";
                name = "Latest ${shortName}";
                files = "target/${target}/release/\${{ github.event.repository.name }}${binarySuffix}";
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
    name = targetToShortName t;
    value = makeWorkflow t;
  }) targets);
}
