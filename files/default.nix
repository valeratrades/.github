# Things are generated at lower level, as this can have unbounded number of members, and each can have its own args, - if I were to gen tomls at this level, we'd start taking a bunch of random args
{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
		agpl = ./licenses/agpl.txt;
  };
  preCommit = import ./pre_commit.nix;
  rs = {
    rustfmt = import ./rs/rustfmt.nix;
    deny = import ./rs/deny.nix;
    toolchain = import ./rs/toolchain.nix;
    config = import ./rs/config.nix;
  };
  py = {
    ruff = import ./py/ruff.nix;
  };
	go = {
		gofumpt = import ./go/gofumpt.nix;
	};
  gitignore = import ./gitignore.nix;
}
