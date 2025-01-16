{ ... }: {
  name = "Cargo Sorted";
  runs-on = "ubuntu-latest";
  steps = [
    { uses = "actions/checkout@v4"; }
    {
      name = "Installation";
      uses = "taiki-e/install-action@v2";
      "with".tool = "cargo-sort";
    }
    {
      name = "Check if Cargo.toml is sorted";
      run = ''
				rm -rf .cargo # cargo-sort can get confused by `[target.x86_64-unknown-linux-gnu]` settings in .cargo/config.toml
        cargo sort -wc
        exit_code=$?
        if [ $exit_code != 0 ]; then
          echo "Cargo.toml is not sorted. Run \`cargo sort -w\` to fix it."
          exit $exit_code
        fi
      '';
    }
  ];
}
