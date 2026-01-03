# Things are generated at lower level, as this can have unbounded number of members, and each can have its own args, - if I were to gen tomls at this level, we'd start taking a bunch of random args
{
  description = "Project conf files";
  licenses = {
    blue_oak = { name = "Blue Oak 1.0.0"; path = ./licenses/blue_oak.md; };
    agpl = { name = "AGPL-3.0"; path = ./licenses/agpl.txt; };
    nsfw = { name = "GLWTS"; path = ./licenses/nsfw.txt; };
  };
  preCommit = import ./pre_commit.nix;
  treefmt = import ./treefmt.nix;
  rust = {
    rustfmt = import ./rust/rustfmt.nix;
    deny = import ./rust/deny.nix;
    toolchain = import ./rust/toolchain.nix;
    config = import ./rust/config.nix;
		clippy = import ./rust/clippy.nix;
		build = import ./rust/build.nix;
  };
  python = {
    ruff = import ./python/ruff.nix;
  };
	golang = {
		gofumpt = import ./golang/gofumpt.nix;
	};
  gitignore = import ./gitignore.nix;
  gitattributes = import ./gitattributes.nix;
}
