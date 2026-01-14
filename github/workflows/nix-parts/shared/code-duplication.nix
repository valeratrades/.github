let
  script = builtins.readFile ./code-duplication.rs;
in
{
  name = "Code Duplication";
  needs = "pre_ci";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name != 'pull_request'";
  timeout-minutes = 15;
  steps = [
    { uses = "actions/checkout@v4"; }
    {
      name = "Setup nightly Rust";
      uses = "dtolnay/rust-toolchain@nightly";
    }
    {
      name = "Install qlty";
      uses = "qltysh/qlty-action/install@main";
    }
    {
      name = "Initialize qlty";
      run = "qlty init --no-ui || true";
    }
    {
      name = "Check for code duplication";
      run = ''
        cat > /tmp/qlty-duplication.rs << 'SCRIPT'
        ${script}
        SCRIPT
        chmod +x /tmp/qlty-duplication.rs
        cargo +nightly -Zscript -q /tmp/qlty-duplication.rs
      '';
    }
  ];
}
