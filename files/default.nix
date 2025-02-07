{ nixpkgs }: {
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	rust = {
    rustfmt = (nixpkgs.formats.toml {}).generate "rustfmt.toml" (import ./rust/rustfmt.nix);
  }.rustfmt.outPath;
  treefmt = ./treefmt.toml;
  #TODO: gitignore: construct from base + each name from provided list
}
