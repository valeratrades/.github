# Generates release workflow for cargo-binstall compatible binary distribution
# Triggers on version tags (v*), builds for multiple platforms, uploads to GitHub Releases
{
  targets ? [
    "x86_64-unknown-linux-gnu"
    "x86_64-apple-darwin"
    "aarch64-apple-darwin"
  ],
  # Optional cargo flags per target (e.g., for --no-default-features on windows)
  cargoFlags ? {},
  # Optional apt dependencies for linux builds
  aptDeps ? [],
}:
let
  targetToOs = target:
    if builtins.match ".*-linux-.*" target != null then "ubuntu-latest"
    else if builtins.match ".*-apple-.*" target != null then "macos-latest"
    else if builtins.match ".*-windows-.*" target != null then "windows-latest"
    else "ubuntu-latest";

  matrixInclude = map (target: {
    inherit target;
    os = targetToOs target;
    cargo_flags = cargoFlags.${target} or "";
  }) targets;
in
{
  # This is a standalone workflow, not a job within errors/warnings/other
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
          uses = "dtolnay/rust-toolchain@nightly";
          "with" = {
            targets = "\${{ matrix.target }}";
          };
        }
      ] ++ (if aptDeps != [] then [{
          name = "Install dependencies";
          "if" = "runner.os == 'Linux'";
          run = ''
            sudo apt-get update
            sudo apt-get install -y ${builtins.concatStringsSep " " aptDeps}
          '';
        }] else []) ++ [
        {
          name = "Build release binary";
          run = "cargo build --release --target \${{ matrix.target }} \${{ matrix.cargo_flags }}";
        }
        {
          name = "Package binary (unix)";
          "if" = "runner.os != 'Windows'";
          run = ''
            cd target/''${{ matrix.target }}/release
            PNAME="''${GITHUB_REPOSITORY##*/}"
            tar -czvf ../../../''${PNAME}-''${{ matrix.target }}.tar.gz ''$PNAME
          '';
        }
        {
          name = "Package binary (windows)";
          "if" = "runner.os == 'Windows'";
          run = ''
            cd target/''${{ matrix.target }}/release
            ''$PNAME = ''$env:GITHUB_REPOSITORY.Split('/')[-1]
            Compress-Archive -Path "''$PNAME.exe" -DestinationPath "../../../''$PNAME-''${{ matrix.target }}.zip"
          '';
          shell = "pwsh";
        }
        {
          name = "Upload artifact";
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "binary-\${{ matrix.target }}";
            path = "*.tar.gz\n*.zip";
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
