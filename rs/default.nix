{
  pkgs ? null,
  nixpkgs ? null,
  # config options
  cranelift ? true,
  deny ? false,
  tracey ? true,
  style ? {},
  # build.rs options
  build ? {},
}:
# Normalize style.modules: { instrument = true; loops = false; } -> "--instrument=true --loops=false"
let
  styleModules = style.modules or {};
  moduleFlags = builtins.concatStringsSep " " (
    builtins.attrValues (builtins.mapAttrs (name: value:
      "--${name}=${if value then "true" else "false"}"
    ) styleModules)
  );
in
# If called with just nixpkgs (for flake description), return description attribute
if nixpkgs != null && pkgs == null then {
  description = ''
Rust project configuration module combining rustfmt, cargo config, and build.rs.

Usage:
```nix
rs = v-utils.rs {
  inherit pkgs;
  cranelift = true;  # Enable cranelift backend (default: true)
  deny = false;      # Copy deny.toml for cargo-deny (default: false)
  tracey = true;     # Enable tracey spec coverage (default: true)
  style = {
    format = true;   # Auto-fix style issues in pre-commit (default: true)
    check = false;   # Error on unfixable style issues (default: false)
    modules = {      # Toggle individual codestyle checks (default: use codestyle defaults)
      instrument = true;  # Require #[instrument] on async functions (default: false)
      loops = true;       # Enforce //LOOP comments on endless loops (default: true)
    };
  };
  build = {
    enable = true;          # Generate build.rs (default: true)
    workspace = {           # Per-directory build.rs modules (default: { "./" = [ "git_version" "log_directives" ]; })
      "./" = [ "git_version" "log_directives" ];
      "./cli" = [ "git_version" "log_directives" { deprecate = { by_version = "2.0.0"; }; } ];
    };
  };
};
```

build.workspace: Map of directories to their build.rs module lists.
  Each directory gets its own build.rs with the specified modules.
  Available modules:
    - "git_version": Embed GIT_HASH at compile time
    - "log_directives": Embed LOG_DIRECTIVES from .cargo/log_directives
    - "deprecate": Deprecation enforcement (see below)

  deprecate module:
    Checks that #[deprecated] items are removed by their specified version.
    Uses the `since` attribute from each #[deprecated(since = "X.Y.Z")] to determine
    when an item should be removed. If current package version >= since version, build fails.

    Configuration:
      - "deprecate"
          Requires all #[deprecated] to have `since` attribute, errors otherwise.

      - { deprecate = { by_version = "X.Y.Z"; }; }
          Sets default version for items without `since`. Items with `since` still
          use their own version.

      - { deprecate = { by_version = "X.Y.Z"; force = true; }; }
          Rewrites ALL `since` attributes to the target version (adds if missing,
          replaces if different), then exits. Useful for bumping all deprecation
          deadlines at once before a release.

Then use in devShell:
```nix
devShells.default = pkgs.mkShell {
  shellHook = rs.shellHook;
  packages = [ ... ] ++ rs.enabledPackages;
};
```

The shellHook will:
- Copy rustfmt.toml to ./rustfmt.toml
- Copy cargo config to ./.cargo/config.toml
- Copy build.rs to each directory in build.workspace (with write permissions for treefmt)
- Copy deny.toml to ./deny.toml (if deny = true)

enabledPackages includes:
- `tracey` - spec coverage tool (if tracey = true)
- `codestyle` - code style linter and formatter (if style.format or style.check is true)
'';
} else

let
  files = import ../files;

  buildEnable = build.enable or true;
  workspace = build.workspace or { "./" = [ "git_version" "log_directives" ]; };

  # Package versions - update these when bumping
  traceyVersion = "1.0.0";
  codestyleVersion = "0.2.3";

  # codestyle from crates.io - requires nightly Rust
  # Projects using this must have rust-overlay applied to their pkgs
  # NB: Must pin the nightly date, as `latest` changes daily and invalidates cargoHash
  codestyleNightly = "2025-10-10";
  codestylePkg =
    let
      nightlyRust = pkgs.rust-bin.nightly.${codestyleNightly}.default;
      nightlyPlatform = pkgs.makeRustPlatform {
        rustc = nightlyRust;
        cargo = nightlyRust;
      };
    in
    nightlyPlatform.buildRustPackage {
      pname = "codestyle";
      version = codestyleVersion;
      src = pkgs.fetchCrate {
        pname = "codestyle";
        version = codestyleVersion;
        hash = "sha256-/mUVNL3hM2t7bzdyw+faxvPWyAZmnAHPBpLY/S3Wsrs=";
      };
      cargoHash = "sha256-yzGjLggCr4xBNMAzBvdR2qc9gKO1il0OkCJbpAJSwSg=";
      nativeBuildInputs = [ pkgs.mold ];
      doCheck = false;
      checkPhase = "";
      cargoTestFlags = [ "--skip" "*" ];
    };

  # Normalize directory path: ensure no trailing slash, then append /build.rs
  # Handles both "./" and "./cli" and "./cli/" correctly
  normalizePath = dir:
    let
      stripped = pkgs.lib.removeSuffix "/" dir;
    in
    if stripped == "." || stripped == "" then "./build.rs" else "${stripped}/build.rs";

  rustfmtFile = files.rust.rustfmt { inherit pkgs; };
  configFile = files.rust.config { inherit pkgs cranelift; };
  denyFile = files.rust.deny { inherit pkgs; };

  # Generate a build file for each workspace directory with its specific modules
  makeBuildFile = modules: files.rust.build { inherit pkgs modules; };

  # Generate install commands for each workspace directory
  workspaceDirs = builtins.attrNames workspace;
  buildHook = if buildEnable then
    builtins.concatStringsSep "\n" (map (dir:
      let
        buildFile = makeBuildFile workspace.${dir};
      in ''
      install -m 644 ${buildFile} ${normalizePath dir}
    '') workspaceDirs)
  else "";

  denyHook = if deny then ''
    cp -f ${denyFile} ./deny.toml
  '' else "";

  # Normalize style config
  styleFormat = style.format or true;
  styleAssert = style.check or false;
  styleEnabled = styleFormat || styleAssert;

  # binstall hook - installs tracey via cargo-binstall at shell entry
  # Uses ~/.cargo/bin as install location
  binstallHook = if tracey then ''
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! command -v tracey &>/dev/null; then
      echo "Installing tracey@${traceyVersion}..."
      cargo binstall tracey@${traceyVersion} --no-confirm -q 2>/dev/null || cargo install tracey@${traceyVersion} -q
    fi
  '' else "";
in
{
  inherit rustfmtFile configFile denyFile styleFormat styleAssert moduleFlags;

  # For backwards compatibility, expose the first build file
  buildFile = makeBuildFile (workspace.${builtins.head workspaceDirs});

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
    ${denyHook}
    ${binstallHook}
  '';

  # cargo-binstall for tracey, codestyle built from source
  enabledPackages =
    [ pkgs.cargo-binstall ] ++
    (if styleEnabled then [ codestylePkg ] else []);
  traceyCheck = tracey;
}