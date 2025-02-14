{}: {
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
      run = "cargo miri test";
      env.MIRIFLAGS = "-Zmiri-strict-provenance";
    }
  ];
}
