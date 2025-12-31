args@{
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
    log_directives = true;  # Embed LOG_DIRECTIVES from .cargo/log_directives (default: true)
    git_version = true;     # Embed GIT_HASH at compile time (default: true)
  };
};
```

Then use in devShell:
```nix
devShells.default = pkgs.mkShell {
  shellHook = rs.shellHook;
};
```

The shellHook will:
- Copy rustfmt.toml to ./rustfmt.toml
- Copy cargo config to ./.cargo/config.toml
- Copy build.rs to ./build.rs (with write permissions for treefmt)
'';
} else

let
  files = import ../files;

  log_directives = build.log_directives or true;
  git_version = build.git_version or true;

  rustfmtFile = files.rust.rustfmt { inherit pkgs; };
  configFile = files.rust.config { inherit pkgs cranelift; };
  buildFile = files.rust.build { inherit pkgs log_directives git_version; };
in
{
  inherit rustfmtFile configFile buildFile;

  shellHook = ''
    mkdir -p ./.cargo
    cp -f ${rustfmtFile} ./rustfmt.toml
    cp -f ${configFile} ./.cargo/config.toml
    install -m 644 ${buildFile} ./build.rs
  '';
}
