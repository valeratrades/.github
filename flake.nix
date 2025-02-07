{
  outputs = { self, nixpkgs }: {
    files = import ./files { inherit nixpkgs; };
		hooks = import ./hooks { inherit nixpkgs; };
		readme_fw = import ./readme_fw { inherit nixpkgs; };
  };
}
