{ pkgs, ... }: 
let
	gitignore = {
		shared = ./gitignore/.gitignore;
		rs = ./gitignore/rs.gitignore;
		go = ./gitignore/go.gitignore;
		py = ./gitignore/py.gitignore;
	};
in
	{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	rust = {
    rustfmt = ./rust/rustfmt.nix;
		deny = ./rust/deny.nix;
		toolchain = ./rust/toolchain.nix;
		config = ./rust/config.nix;
  };


  #TODO: gitignore: construct from base + each name from provided list
}
