{ pkgs }: {
	src = ./.;
	hooks = {
		treefmt = {
			enable = true;
			settings = {
				#BUG: this option does NOTHING
				fail-on-change = false; # that's GHA's job, pre-commit hooks stricty *do*
				formatters = with pkgs; [
					nixpkgs-fmt
				];
			};
		};
		# fails randomly at times
		#trim-trailing-whitespace = {
		#	enable = true;
		#};
	};
}
