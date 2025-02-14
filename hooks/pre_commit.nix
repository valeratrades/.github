{ pkgs, prjName }:
let
  script = ''
    config_filepath="''${HOME}/.config/${prjName}.toml"
    config_dir="''${HOME}/.config/${prjName}"
    if [ -f "$config_filepath" ] || [ -d "$config_dir" ]; then
      echo "Copying project's toml config to examples/"
      mkdir -p ./examples

      if [ -f "$config_dir" ]; then
        cp -f "$config_filepath" ./examples/config.toml
      else
        [ -d ./examples/config ] || cp -r "$config_dir" ./examples/config
      fi

      git add examples/

      if [ $? -ne 0 ]; then
        echo "Failed to copy project's toml config to examples"
        exit 1
      fi
    fi

    if [ -f "Cargo.toml" ]; then
      cargo sort --workspace --grouped --order package,lints,dependencies,dev-dependencies,build-dependencies,features
      fd Cargo.toml --type f --exec git add {} \;
    fi

    rm commit >/dev/null 2>&1 # remove commit message text file if it exists
    echo "Ran custom pre-commit hooks"
  '';
in
pkgs.writeText "pre-commit-hook.sh" script
