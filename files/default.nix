{ pkgs ? import <nixpkgs> {} }: {
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
  rust = {
    rustfmt.toml = ./rust/rustfmt.toml;
  };
  treefmt = ./treefmt.toml;
  #TODO: gitignore: construct from base + each name from provided list
}
