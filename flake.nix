{
  outputs = { self, nixpkgs }: {
    files = import ./files { inherit nixpkgs; };
		hooks = import ./hooks { inherit nixpkgs; };
		readme-fw = (import ./readme_fw { inherit nixpkgs; }).generator;
  };
}
