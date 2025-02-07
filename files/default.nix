{ nixpkgs }: {
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	rust = {
    rustfmt = ./rust/rustfmt.nix;
  };
  treefmt = ./treefmt.toml;
  #TODO: gitignore: construct from base + each name from provided list
}
