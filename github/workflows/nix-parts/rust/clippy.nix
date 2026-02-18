 {
  name = "Clippy";
  needs = "pre_ci";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name != 'pull_request'";
  timeout-minutes = 45;
  steps = [
    { uses = "actions/checkout@v4"; }
    { uses = "dtolnay/rust-toolchain@clippy"; }
		{
			name = "Download modified by pre-ci Cargo.toml files";
			uses = "actions/download-artifact@v4";
			"with".name = "modified-cargo-files";
		}
    { run = "rm -f .cargo/config.toml .cargo/config"; } # it can have eg `threads=8`; which could lead to races when reasoning about macros
    { run = "cargo clippy --tests -- -Dwarnings"; } #-Dclippy::all #-Dclippy::pedantic
  ];
}
