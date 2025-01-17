#HACK: at the current moment (2024/01/16) is slower than installing with binstall. However, the other thing is having some weird issues which I can't debug, so here we go with defaults.
{ ... }: {
  name = "Cargo Sorted";
  runs-on = "ubuntu-latest";
  steps = [
    {
      uses = "DevinR528/cargo-sort@v1.0.4";
    }
  ];
}
