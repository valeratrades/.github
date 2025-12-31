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
    dirs = [ "./" ];        # Directories to place build.rs in (default: [ "./" ])
    log_directives = true;  # Embed LOG_DIRECTIVES from .cargo/log_directives (default: true)
    git_version = true;     # Embed GIT_HASH at compile time (default: true)
  };
};
```

build.dirs: For workspaces, specify the directory of each `cargo install`-able entrypoint.
  Example: `dirs = [ "./cli" "./server" ];` places build.rs in both ./cli/build.rs and ./server/build.rs.
  Multiple entries are supported when the workspace has more than one standalone binary crate.

Then use in devShell:
```nix
devShells.default = pkgs.mkShell {
  shellHook = rs.shellHook;
};
```

The shellHook will:
- Copy rustfmt.toml to ./rustfmt.toml
- Copy cargo config to ./.cargo/config.toml
- Copy build.rs to each directory in build.dirs (with write permissions for treefmt)
'';
} else

let
  files = import ../files;

  buildEnable = build.enable or true;
  buildDirs = build.dirs or [ "./" ];
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
  buildFile = files.rust.build { inherit pkgs log_directives git_version; };

  buildHook = if buildEnable then
    builtins.concatStringsSep "\n" (map (dir: ''
      install -m 644 ${buildFile} ${normalizePath dir}
    '') buildDirs)
  else "";
in
{
  inherit rustfmtFile configFile buildFile;

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    ${buildHook}
  '';
}
