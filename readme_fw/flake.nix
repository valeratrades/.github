{
  description = "Nix-based Readme framework";

  outputs = { self }: {
    __functor = _: import ./readme_fw.nix;
  };
}
