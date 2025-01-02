{
  description = "GitHub workflow parts";
  outputs = { self }: {
    shared = ./shared.nix;
    tokei = ./tokei.nix;
    test = ./test.nix;
    doc = ./doc.nix;
    miri = ./miri.nix;
    clippy = ./clippy.nix;
    machete = ./machete.nix;
    sort = ./sort.nix;
  };
}
