```nix
readme = (readme-fw { inherit pkgs; pname = "readme-fw"; lastSupportedVersion = "nightly-1.86"; rootDir = ./.; licenses = [{ name = "Blue Oak 1.0.0"; outPath = "LICENSE"; }]; badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ]; }).combined;

devShells.defaut = pkgs.mkShell {
	shellHook = ''
		cp -f ${readme} ./README.md
	'';
}
```
