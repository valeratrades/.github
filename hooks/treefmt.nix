{
pkgs,
...
	}:
	(pkgs.formats.toml { }).generate "" {
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
		rust-leptos = {
			command = "leptosfmt";
			options = ["--tab-spaces" "2" "--max-width" "120"];
			includes = ["*.rs"];
		};
	};
}
