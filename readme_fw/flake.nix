{
  description = "Example usage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23e89b7da85c3640bbc2173fe04f4bd114342367";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
				files = import ../files { inherit nixpkgs; };
        readme-fw = import ./.;

				pname = "readme-fw";
        readme = (readme-fw { inherit pkgs pname; lastSupportedVersion = "nightly-1.86"; rootDir = ./.; licenses = [{ name = "Blue Oak 1.0.0"; outPath = "LICENSE"; }]; badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ]; }).combined;
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook =
            ''
						cp -f ${files.licenses.blue_oak} ./LICENSE
						cp -f ${(import files.gitignore) { inherit pkgs; langs = [];}} ./.gitignore

						cp -f ${readme} ./README.md
						'';
				};
      }
    );
}

