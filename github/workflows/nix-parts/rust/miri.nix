{
	name = "Miri";
	needs = "pre_ci";
	"if" = "needs.pre_ci.outputs.continue";
	runs-on = "ubuntu-latest";
	timeout-minutes = 45;
	steps = [
		{ uses = "actions/checkout@v4"; }
		{ uses = "dtolnay/rust-toolchain@miri"; }
		{
			name = "Download modified by pre-ci Cargo.toml files";
			uses = "actions/download-artifact@v4";
			"with".name = "modified-cargo-files";
		}
		{ run = "cargo miri setup"; }
		{
			run = "cargo miri test --lib --bins"; # normally, `--lib` and `--bins` is exactly what's needed in 99% os cases. If ever run into needing different ones, - add optional flag setting with these as default
			env.MIRIFLAGS = "-Zmiri-strict-provenance";
		}
	];
}
