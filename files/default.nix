# Things are generated at lower level, as this can have unbounded number of members, and each can have its own args, - if I were to gen tomls at this level, we'd start taking a bunch of random args
{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
		agpl = ./licenses/agpl.txt;
  };
  preCommit = import ./pre_commit.nix;
  rust = {
    rustfmt = import ./rust/rustfmt.nix;
    deny = import ./rust/deny.nix;
    toolchain = import ./rust/toolchain.nix;
    config = import ./rust/config.nix;
  };
  python = {
    ruff = import ./python/ruff.nix;
  };
	golong = {
		gofumpt = import ./golong/gofumpt.nix;
	};
  gitignore = import ./gitignore.nix;
}
