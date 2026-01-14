{
  name = "Code Duplication";
  needs = "pre_ci";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name != 'pull_request'";
  timeout-minutes = 15;
  steps = [
    { uses = "actions/checkout@v4"; }
    {
      uses = "actions/checkout@v4";
      "with" = {
        repository = "valeratrades/.github";
        path = "my_gh_stuff";
        sparse-checkout = "github/workflows";
        sparse-checkout-cone-mode = false;
      };
    }
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
      run = "qlty init --yes --no-upgrade-check";
    }
    {
      name = "Check for code duplication";
      run = "cargo +nightly -Zscript -q my_gh_stuff/github/workflows/code-duplication.rs";
    }
  ];
}
