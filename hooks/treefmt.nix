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
			includes = ["*.rs"];
			options = ["--edition" "2024"]; # code duplication with formatter in dev-shell, but rust ecosystem is not smart enough yet to avoid it 
		};
		# Does not seem to work (treefmt feels VERY raw)
		rust-leptos = {
			command = "leptosfmt";
			options = ["--tab-spaces" "2" "--max-width" "100"];
			includes = ["*.rs"];
		};
	};
}
