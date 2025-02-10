{ nixpkgs }: 
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
	gitignore = builtins.trace ./gitignore.nix ./gitignore.nix;
}
