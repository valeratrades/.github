{ pkgs, pname }:
let
  script = ''
    config_filepath="''${HOME}/.config/${pname}.toml"
    config_dir="''${HOME}/.config/${pname}"
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
      cargo sort --workspace --grouped
			cargo sort-derives
      fd Cargo.toml --type f --exec git add {} \;
    fi

    current_branch=$(git symbolic-ref --short HEAD)
    if [ -f "Cargo.toml" ] && [ "$current_branch" == "release"* ]; then
      cargo sort-derives # don't know how much it will change, so can't add it to the commit automatically. And as such desirable to reduce frequency with which it is run.
    fi

    rm commit >/dev/null 2>&1 # remove commit message text file if it exists
    echo "Ran custom pre-commit hooks"
  '';
in
pkgs.writeText "pre-commit-hook.sh" script
