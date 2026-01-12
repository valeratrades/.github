{ pkgs, lib ? pkgs.lib }: {
	src = ./.;
	hooks = {
		treefmt = {
			enable = true;
			# Override entry to re-stage files after formatting.
			# This prevents pre-commit from detecting file changes and re-running hooks.
			entry = lib.mkForce "bash -c 'treefmt --no-cache \"$@\" && git add -u' --";
			# Must be serial since `git add -u` needs exclusive access to the index lock
			require_serial = true;
			settings = {
				fail-on-change = false; # GHA's job, pre-commit hooks strictly *do*
				formatters = with pkgs; [
					nixpkgs-fmt
				];
			};
		};
	};
}
