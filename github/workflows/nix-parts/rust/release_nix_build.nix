# Nix-native release workflow (preserved for future use)
#
# Uses `nix build` for reproducible builds instead of cargo build + native deps.
# Linux targets build packages.static (musl-static), Darwin builds packages.default.
#
# Requires the consuming flake.nix to define:
#   packages.x86_64-linux.static  - musl cross-compiled static binary
#   packages.aarch64-darwin.default - native darwin binary
#
# Example integration: https://github.com/valeratrades/social_networks/actions/runs/22123617429/job/63948907785
# Note: the musl side in that repo's flake.nix (pkgsCross.musl64 + makeRustPlatform + pkgsStatic.openssl)
# was meant to be proceduralized by v-utils later, so each consuming repo wouldn't need to define it manually.
#
# Tradeoff: ~3-4x slower than native cargo build on first CI run (nix builds toolchain from source).
# With warm nix cache, narrows to ~1.5-2x. Gives exact reproducibility with local dev environment.
{
  # Set to true to use defaults, or customize individual fields
  # Accepts both `default` and `defaults` as aliases
  defaults ? false,
  default ? defaults,
  # Targets as Nix system strings. Each gets a GHA runner + nix build.
  # Linux targets produce musl-static binaries (packages.static) for portability.
  targets ? [
    "x86_64-linux"
    "aarch64-darwin"
  ],
  # Install config from parent - no longer used for release (nix build handles deps)
  installConfig ? {},
  # Legacy params (deprecated, ignored)
  install ? {},
  aptDeps ? [],
  cargoFlags ? {},
}:
let
  nixSystemToGhaOs = system:
    if builtins.match ".*-linux" system != null then "ubuntu-latest"
    else if builtins.match ".*-darwin" system != null then "macos-latest"
    else "ubuntu-latest";

  # Map nix system to cargo triple for tarball naming (cargo-binstall compat)
  nixSystemToCargoTriple = system:
    if system == "x86_64-linux" then "x86_64-unknown-linux-musl"
    else if system == "aarch64-linux" then "aarch64-unknown-linux-musl"
    else if system == "x86_64-darwin" then "x86_64-apple-darwin"
    else if system == "aarch64-darwin" then "aarch64-apple-darwin"
    else system;

  isLinux = system: builtins.match ".*-linux" system != null;

  matrixInclude = map (system: {
    inherit system;
    os = nixSystemToGhaOs system;
    cargo_triple = nixSystemToCargoTriple system;
    # Linux builds use packages.static (musl) for portable binaries
    nix_pkg = if isLinux system then ".#packages.${system}.static" else ".#packages.${system}.default";
  }) targets;
in
{
  standalone = true;

  name = "Release";
  on = {
    push = {
      tags = [ "v[0-9]+.*" ];
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
    build = {
      strategy = {
        matrix = {
          include = matrixInclude;
        };
      };
      runs-on = "\${{ matrix.os }}";
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
          run = "set -o pipefail && nix build \${{ matrix.nix_pkg }} --no-link --print-out-paths | tee /tmp/nix-out";
        }
        {
          name = "Package binary";
          run = ''
            PNAME="''${GITHUB_REPOSITORY##*/}"
            OUT=$(cat /tmp/nix-out)
            cp "''${OUT}/bin/''${PNAME}" ./
            tar -czvf "''${PNAME}-''${{ matrix.cargo_triple }}.tar.gz" "''${PNAME}"
          '';
        }
        {
          name = "Upload artifact";
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "binary-\${{ matrix.cargo_triple }}";
            path = "*.tar.gz";
          };
        }
      ];
    };
    release = {
      needs = "build";
      runs-on = "ubuntu-latest";
      steps = [
        {
          uses = "actions/download-artifact@v4";
          "with" = {
            path = "artifacts";
            merge-multiple = true;
          };
        }
        {
          name = "Create Release";
          uses = "softprops/action-gh-release@v2";
          "with" = {
            files = "artifacts/*";
          };
          env = {
            GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
          };
        }
      ];
    };
  };
}
