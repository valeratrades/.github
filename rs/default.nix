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
  codestyleVersion = "0.1.1";

  traceyPkg = pkgs.rustPlatform.buildRustPackage {
    pname = "tracey";
    version = traceyVersion;
    src = pkgs.fetchFromGitHub {
      owner = "bearcove";
      repo = "tracey";
      rev = "71cfc9d4115612467b857c868a90cc6d90ed79f7";
      hash = "sha256-maVPj9/PZzZDEmtMjemeuOCctDrU3JXaBNDwjFTRpks=";
    };
    cargoHash = "sha256-pk9Ky+/5P88zAbSJKbUwyvLNFIlHJzwqQCEQrorjlk0=";
    cargoBuildFlags = [ "-p" "tracey" ];
    doCheck = false;
  };

  # codestyle from crates.io - requires nightly Rust
  # Projects using this must have rust-overlay applied to their pkgs
  codestylePkg =
    let
      nightlyRust = pkgs.rust-bin.nightly.latest.default;
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
        hash = "sha256-h+Y6JYsMfoSFajjYZhhakFdV2d4B2LeGYiejiqF9LjQ=";
      };
      cargoHash = "sha256-r8NQv13fdgju4Ik3hQQ8uyJUq5G9fhJo3RadY9vS8fM=";
      doCheck = false;
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
in
{
  inherit rustfmtFile configFile denyFile styleFormat styleAssert;

  # For backwards compatibility, expose the first build file
  buildFile = makeBuildFile (workspace.${builtins.head workspaceDirs});

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
    ${denyHook}
  '';

  enabledPackages =
    (if tracey then [ traceyPkg ] else []) ++
    (if styleEnabled then [ codestylePkg ] else []);
  traceyCheck = tracey;
}
