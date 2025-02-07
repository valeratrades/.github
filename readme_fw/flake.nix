{
  description = ''
# Nix Readme Framework
Generates a README.md with configurable badges and sections.

Type: Function
Args:
  - pkgs: Package set with lib and runCommand
	- root: Path, under which we should search for assets dir
  - prj_name: Project name (string)
  - loc: Lines of code (string | int)
  - license: List of license definitions
  - badges: List of badge names to include

Example:
```nix
let
  license = [
    { name = "blue_oak"; out_path = "LICENSE"; }
    { name = "mit license"; out_path = "LICENSE-MIT"; }
    { name = "apache license"; out_path = "LICENSE-APACHE"; }
  ];
in
(import ./readme_fw.nix) {
  inherit pkgs;
  prj_name = "my_prj";
  loc = "500";
  inherit licenses;
  badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ];
}
```
'';

  outputs = { self }: {
    __functor = _: import ./readme_fw.nix;
  };
}
