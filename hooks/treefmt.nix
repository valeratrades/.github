{
pkgs,
...
	}:
	(pkgs.formats.yaml { }).generate "" {
	formatter = {
		nix = {
			command = "nixpkgs-fmt";
			includes = ["*.nix"];
		};
		rust = {
			command = "rustfmt";
			options = ["--edition" "2024"];
			includes = ["*.rs"];
		};
	};
}
