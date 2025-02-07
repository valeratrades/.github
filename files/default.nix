{ nixpkgs }: {
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
  rust = {
    #rustfmt = ./rust/rustfmt.toml;
		rustfmt = let
			rustfmtConf = (import ./rust/rustfmt.nix);
			in
			(nixpkgs.formats.toml {}).generate "rustfmt.toml" rustfmtConf;
  };
  treefmt = ./treefmt.toml;
  #TODO: gitignore: construct from base + each name from provided list
}
