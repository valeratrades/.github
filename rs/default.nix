{
  pkgs ? null,
  nixpkgs ? null,
  # config options
  cranelift ? true,
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
  build = {
    enable = true;          # Generate build.rs (default: true)
    log_directives = true;  # Embed LOG_DIRECTIVES from .cargo/log_directives (default: true)
    git_version = true;     # Embed GIT_HASH at compile time (default: true)
    workspace = {           # Workspace directories with per-directory config (required)
      "./" = {
        deprecate = {       # Functions to remove at specific versions (default: {})
          "v1.0" = [ "old_function" ];
          "1.2.3" = [ "another_old_func" "yet_another" ];
        };
      };
      # For workspaces with multiple crates:
      # "./cli" = { deprecate = {}; };
      # "./server" = { deprecate = { "2.0" = [ "legacy_handler" ]; }; };
    };
  };
};
```

build.workspace: Map of directories to their configuration.
  Each directory gets its own build.rs with the specified deprecations.
  Example: `workspace = { "./" = {}; "./cli" = {}; };` places build.rs in both locations.

deprecate: Schedule function removal at specific versions.
  When CARGO_PKG_VERSION >= specified version, build.rs will search for the listed functions
  in the src/ directory and fail the build if any are found. Version prefixes (v) are optional.
  This ensures deprecated code is removed before publishing a new version.

Then use in devShell:
```nix
devShells.default = pkgs.mkShell {
  shellHook = rs.shellHook;
};
```

The shellHook will:
- Copy rustfmt.toml to ./rustfmt.toml
- Copy cargo config to ./.cargo/config.toml
- Copy build.rs to each directory in build.workspace (with write permissions for treefmt)
'';
} else

let
  files = import ../files;

  buildEnable = build.enable or true;
  workspace = build.workspace or { "./" = {}; };
  log_directives = build.log_directives or true;
  git_version = build.git_version or true;

  # Normalize directory path: ensure no trailing slash, then append /build.rs
  # Handles both "./" and "./cli" and "./cli/" correctly
  normalizePath = dir:
    let
      stripped = pkgs.lib.removeSuffix "/" dir;
    in
    if stripped == "." || stripped == "" then "./build.rs" else "${stripped}/build.rs";

  rustfmtFile = files.rust.rustfmt { inherit pkgs; };
  configFile = files.rust.config { inherit pkgs cranelift; };

  # Generate a build file for each workspace directory with its specific deprecations
  makeBuildFile = dir: dirConfig:
    let
      deprecate = dirConfig.deprecate or {};
    in
    files.rust.build { inherit pkgs log_directives git_version deprecate; };

  # Generate install commands for each workspace directory
  workspaceDirs = builtins.attrNames workspace;
  buildHook = if buildEnable then
    builtins.concatStringsSep "\n" (map (dir:
      let
        buildFile = makeBuildFile dir workspace.${dir};
      in ''
      install -m 644 ${buildFile} ${normalizePath dir}
    '') workspaceDirs)
  else "";
in
{
  inherit rustfmtFile configFile;

  # For backwards compatibility, expose the first build file
  buildFile = makeBuildFile (builtins.head workspaceDirs) (workspace.${builtins.head workspaceDirs});

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
  '';
}
