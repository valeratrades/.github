{ nixpkgs }: {
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	rust = {
    rustfmt = ./rust/rustfmt.nix;
  };
  #TODO: gitignore: construct from base + each name from provided list
}
