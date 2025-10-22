{ pkgs, pname }:
let
  script = ''
    config_filepath="''${HOME}/.config/${pname}.toml"
    config_dir="''${HOME}/.config/${pname}"
    if [ -f "$config_filepath" ] || [ -d "$config_dir" ]; then
      echo "Copying project's toml config to examples/"
      mkdir -p ./examples

      if [ -f "$config_filepath" ]; then
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
      cargo sort --workspace --grouped
			cargo sort-derives
      fd Cargo.toml --type f --exec git add {} \;
    fi

    rm commit >/dev/null 2>&1 # remove commit message text file if it exists
    echo "Ran custom pre-commit hooks"
  '';
in
pkgs.writeText "pre-commit-hook.sh" script
