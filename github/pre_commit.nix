{ pkgs, pname, semverChecks ? false, traceyCheck ? false, styleCheck ? true, nukeSnapsCheck ? true }:
let
  semverChecksCmd = if semverChecks then "cargo semver-checks" else "";
  traceyCmd = if traceyCheck then ''
    if [ -f ".config/tracey/config.kdl" ]; then
      tracey --check
    fi
  '' else "";
  styleCmd = if styleCheck then "rust_style" else "";
  # Nuke .pending-snap files (insta crate snapshots, - must always inline. Otherwise what's the point.)
  nukeSnapsCmd = if nukeSnapsCheck then ''
    fd -e pending-snap -x rm {} \;
  '' else "";
  script = ''
    config_filepath_nix="''${HOME}/.config/${pname}.nix"
    config_filepath_toml="''${HOME}/.config/${pname}.toml"
    config_dir="''${HOME}/.config/${pname}"

    # .nix takes priority over .toml
    if [ -f "$config_filepath_nix" ]; then
      echo "Copying project's nix config to examples/"
      mkdir -p ./examples
      cp -f "$config_filepath_nix" ./examples/config.nix
      git add examples/

      if [ $? -ne 0 ]; then
        echo "Failed to copy project's nix config to examples"
        exit 1
      fi
    elif [ -f "$config_filepath_toml" ] || [ -d "$config_dir" ]; then
      echo "Copying project's toml config to examples/"
      mkdir -p ./examples

      if [ -f "$config_filepath_toml" ]; then
        cp -f "$config_filepath_toml" ./examples/config.toml
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
      ${semverChecksCmd}
      ${traceyCmd}
      ${styleCmd}
      ${nukeSnapsCmd}
    fi

    rm commit >/dev/null 2>&1 # remove commit message text file if it exists
    echo "Ran custom pre-commit hooks"
  '';
in
pkgs.writeText "pre-commit-hook.sh" script
