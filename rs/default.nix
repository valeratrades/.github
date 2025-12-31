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
    workspace = {           # Per-directory build.rs modules (default: { "./" = [ "git_version" "log_directives" ]; })
      "./" = [ "git_version" "log_directives" ];
      "./cli" = [ "git_version" "log_directives" { deprecate = "2.0.0"; } ];
    };
  };
};
```

build.workspace: Map of directories to their build.rs module lists.
  Each directory gets its own build.rs with the specified modules.
  Available modules:
    - "git_version": Embed GIT_HASH at compile time
    - "log_directives": Embed LOG_DIRECTIVES from .cargo/log_directives
    - { deprecate = "VERSION"; }: Fail build if #[deprecated] items exist at VERSION

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
  workspace = build.workspace or { "./" = [ "git_version" "log_directives" ]; };

  # Normalize directory path: ensure no trailing slash, then append /build.rs
  # Handles both "./" and "./cli" and "./cli/" correctly
  normalizePath = dir:
    let
      stripped = pkgs.lib.removeSuffix "/" dir;
    in
    if stripped == "." || stripped == "" then "./build.rs" else "${stripped}/build.rs";

  rustfmtFile = files.rust.rustfmt { inherit pkgs; };
  configFile = files.rust.config { inherit pkgs cranelift; };

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
in
{
  inherit rustfmtFile configFile;

  # For backwards compatibility, expose the first build file
  buildFile = makeBuildFile (workspace.${builtins.head workspaceDirs});

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
  '';
}
