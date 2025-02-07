{
  outputs = { self, nixpkgs }: {
    files = import ./files { inherit nixpkgs; };
  };
}
