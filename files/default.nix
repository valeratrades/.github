{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	preCommit = ./pre_commit.nix;
  rust = {
    rustfmt = ./rust/rustfmt.nix;
    deny = ./rust/deny.nix;
    toolchain = ./rust/toolchain.nix;
    config = ./rust/config.nix;
  };
	python = {
		ruff = ./python/ruff.nix;
	};
	gitignore = ./gitignore.nix;
}
