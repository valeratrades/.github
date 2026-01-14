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
      name = "Check for nightly toolchain";
      id = "check-nightly";
      run = ''
        if rustup toolchain list | grep -q nightly; then
          echo "has_nightly=true" >> $GITHUB_OUTPUT
        else
          echo "::warning::Nightly toolchain not available, skipping code duplication check"
          echo "has_nightly=false" >> $GITHUB_OUTPUT
        fi
      '';
    }
    {
      name = "Setup nightly Rust";
      "if" = "steps.check-nightly.outputs.has_nightly == 'true'";
      uses = "dtolnay/rust-toolchain@nightly";
    }
    {
      name = "Install qlty";
      "if" = "steps.check-nightly.outputs.has_nightly == 'true'";
      uses = "qltysh/qlty-action/install@main";
    }
    {
      name = "Initialize qlty";
      "if" = "steps.check-nightly.outputs.has_nightly == 'true'";
      run = "qlty init --no-ui || true";
    }
    {
      name = "Check for code duplication";
      "if" = "steps.check-nightly.outputs.has_nightly == 'true'";
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
