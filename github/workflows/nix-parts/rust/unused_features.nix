{
  name = "Unused Features";
  runs-on = "ubuntu-latest";
  steps = [
    { uses = "actions/checkout@v4"; }
    {
      name = "Installation";
      uses = "taiki-e/install-action@v2";
      "with".tool = "cargo-unused-features";
    }
    {
      name = "Analyze Unused Features";
      run = ''
        cargo unused-features analyze
      '';
    }
    {
      name = "Build Report";
      run = ''
        cargo unused-features build-report --output report.json
      '';
    }
    {
      name = "Check for Unused Features";
      run = ''
        if [ -f report.json ] && [ "$(cat report.json)" != "[]" ]; then
          echo "Found unused features:"
          cat report.json
          exit 1
        fi
      '';
    }
  ];
}
