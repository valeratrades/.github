{ package ? null }:
let
  cargoDocsCmd = if package != null
                 then "cargo docs-rs -p ${package}"
                 else "cargo docs-rs";
in
{
  name = "Documentation";
  needs = "pre_ci";
  "if" = "needs.pre_ci.outputs.continue";
  runs-on = "ubuntu-latest";
  timeout-minutes = 45;
  env.RUSTDOCFLAGS = "-Dwarnings";
  steps = [
    { uses = "actions/checkout@v4"; }
    { uses = "dtolnay/rust-toolchain@nightly"; }
			{
		name = "Download modified by pre-ci Cargo.toml files";
		uses = "actions/download-artifact@v4";
		"with".name = "modified-cargo-files";
	}
    { uses = "dtolnay/install@cargo-docs-rs"; }
    { run = cargoDocsCmd; }
  ];
}
