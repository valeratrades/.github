# Things are generated at lower level, as this can have unbounded number of members, and each can have its own args, - if I were to gen tomls at this level, we'd start taking a bunch of random args
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
