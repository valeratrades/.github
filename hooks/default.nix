{ nixpkgs }: {
  description = "Random tools for interfacing with github hooks";
  appendCustom = ./append_custom.rs;
  treefmt = ./treefmt.nix;
}
