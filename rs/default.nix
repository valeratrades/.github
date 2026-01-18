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
  # rust toolchain package - required to prepend to PATH so nix rust takes precedence over rustup
  rust,
}:
# Normalize style.modules: { instrument = true; loops = false; } -> "--instrument=true --loops=false"
# Accepts both booleans and strings as values
let
  styleModules = style.modules or {};
  # Convert value to string, handling both bool and string inputs
  valueToString = value:
    if builtins.isBool value then (if value then "true" else "false")
    else builtins.toString value;
  moduleFlags = builtins.concatStringsSep " " (
    builtins.attrValues (builtins.mapAttrs (name: value:
      "--${builtins.replaceStrings ["_"] ["-"] name}=${valueToString value}"
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
  inherit pkgs rust;  # rust is the nix toolchain package
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
- Prepend nix rust to PATH so it takes precedence over rustup shims
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
  # Use partial semver (major.minor) for tools where patch updates are safe
  traceyVersion = "1.0";
  codestyleVersion = "0.2";

  # codestyle installed via binstall (same as tracey)
  # Building from source fails in nix sandbox due to TMPDIR issues during cargo build

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
  buildRustfmtFile = ../files/rust/build/rustfmt.toml;
  buildHook = if buildEnable then
    builtins.concatStringsSep "\n" (map (dir:
      let
        buildFile = makeBuildFile workspace.${dir};
        targetPath = normalizePath dir;
      in ''
      install -m 644 ${buildFile} ${targetPath}
      rustfmt --config-path ${buildRustfmtFile} ${targetPath}
    '') workspaceDirs)
  else "";

  denyHook = if deny then ''
    cp -f ${denyFile} ./deny.toml
  '' else "";

  # Normalize style config
  styleFormat = style.format or true;
  styleAssert = style.check or false;
  styleEnabled = styleFormat || styleAssert;

  # binstall hook - installs/upgrades tracey via cargo-binstall at shell entry
  # Uses ~/.cargo/bin as install location
  # Checks version and upgrades if installed version differs from expected
  # Note: codestyle is installed lazily at pre-commit time, not here
  binstallHook = ''
    export PATH="$HOME/.cargo/bin:$PATH"
  '' + (if tracey then ''
    _tracey_installed=$(cargo install --list 2>/dev/null | grep "^tracey v" | grep -oP '\d+\.\d+\.\d+' || echo "")
    if [[ ! "$_tracey_installed" =~ ^${traceyVersion}\. ]]; then
      echo "Installing tracey@${traceyVersion}..."
      cargo binstall tracey@${traceyVersion} --no-confirm -q 2>/dev/null || cargo install tracey@${traceyVersion} -q
    fi
  '' else "");

  # Lazy install hook for codestyle - called from pre-commit, not shell entry
  codestyleLazyInstall = if styleEnabled then ''
    _codestyle_installed=$(codestyle --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
    if [[ ! "$_codestyle_installed" =~ ^${codestyleVersion}\. ]]; then
      echo "Installing codestyle@${codestyleVersion}..."
      cargo binstall codestyle@${codestyleVersion} --no-confirm -q 2>/dev/null || cargo install codestyle@${codestyleVersion} -q
    fi
  '' else "";
in
{
  inherit rustfmtFile configFile denyFile styleFormat styleAssert moduleFlags codestyleLazyInstall;

  # For backwards compatibility, expose the first build file
  buildFile = makeBuildFile (workspace.${builtins.head workspaceDirs});

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
    ${denyHook}
    ${binstallHook}
    # Prepend nix rust to PATH so it takes precedence over rustup shims in ~/.cargo/bin.
    # This is critical for trybuild tests which spawn cargo subprocesses.
    # Must be AFTER binstallHook which also modifies PATH.
    export PATH="${rust}/bin:$PATH"
  '';

  # cargo-binstall for tracey and codestyle
  enabledPackages = [ pkgs.cargo-binstall ];
  traceyCheck = tracey;
}