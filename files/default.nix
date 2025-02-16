#TODO: change to gen tomls here
{ pkgs }: 
{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
	preCommit = import ./pre_commit.nix {inherit pkgs;};
  rust = {
    rustfmt = ./rust/rustfmt.nix;
    deny = ./rust/deny.nix;
    toolchain = ./rust/toolchain.nix;
    config = ./rust/config.nix;
  };
	gitignore = ./gitignore.nix;
}
