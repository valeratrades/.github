{ lastSupportedVersion ? null }:
let
	# Warn if lastSupportedVersion is not provided
	_ = if lastSupportedVersion == null then
		builtins.trace "WARNING: lastSupportedVersion not provided for rust-tests. Matrix will only contain 'nightly'."
		null
	else null;

	rustcVersions = if lastSupportedVersion == null then
		[ "nightly" ]
	else
		[
			"nightly"
			"${lastSupportedVersion}"
		];
in
{
  name = "Rust \${{matrix.rust}}";
  needs = "pre_ci";
  "if" = "needs.pre_ci.outputs.continue";
  runs-on = "ubuntu-latest";
  strategy = {
    fail-fast = false;
    matrix.rust = rustcVersions;
  };
  timeout-minutes = 45;
  steps = [
    {
      uses = "actions/checkout@v4";
    }
    {
      uses = "dtolnay/rust-toolchain@master";
      "with".toolchain = "\${{matrix.rust}}";
    }
    {
      # test this works
      name = "Set RUSTFLAGS for release branch";
      run = "echo \"RUSTFLAGS=-Dwarnings\" >> $GITHUB_ENV";
      "if" = "github.ref == 'refs/heads/release'";
    }
    {
      name = "Enable type layout randomization";
      run = "echo RUSTFLAGS=\${RUSTFLAGS}\\ -Zrandomize-layout\\ --cfg=exhaustive >> $GITHUB_ENV";
      "if" = "matrix.rust == 'nightly'";
    }
				{
			name = "Download modified by pre-ci Cargo.toml files";
			uses = "actions/download-artifact@v4";
			"with".name = "modified-cargo-files";
		}
    # not sure why dtolnay has this
    #{ run = "cargo check --locked"; }
    { run = "cargo update"; }
    { run = "cargo check"; }
    { run = "cargo test"; }
    #TODO: figure this out
    #  if: matrix.os == 'ubuntu' && matrix.rust == 'nightly'
    #- run: cargo run -- expand --manifest-path tests/Cargo.toml > expand.rs && diff tests/lib.expand.rs expand.rs
  ];
}
