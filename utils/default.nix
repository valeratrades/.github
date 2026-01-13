let
  # Helper to allow both `default` and `defaults` as aliases for the same attribute.
  # When one is provided, both are set to the same value. When neither is provided, neither is set
  # (allowing downstream `or` fallbacks to work correctly).
  # Usage: let cfg = optionalDefaults args; in cfg.default or someDefault
  optionalDefaults = args:
    let
      hasDefault = args ? default;
      hasDefaults = args ? defaults;
      # Only add default/defaults if at least one was explicitly provided
      value = if hasDefault then args.default else args.defaults;
    in
    if hasDefault || hasDefaults
    then args // { default = value; defaults = value; }
    else args;

  maskSecret = s: isSecret:
    if !isSecret then s else
    let len = builtins.stringLength s;
    in if len < 8 then "[REDACTED]"
       else (builtins.substring 0 2 s) + "..." + (builtins.substring (len - 2) 2 s);

  maskSh = ''
    _mask() {
      val="$1"; secret="$2"
      if [ "$secret" = "true" ]; then
        if [ ''\${#val} -lt 8 ]; then
          printf "[REDACTED]"
        else
          printf "%s..%s" "''\${val:0:2}" "''\${val: -2}"
        fi
      else
        printf "%s" "$val"
      fi
    }
  '';

  # Generate shell command to check if a crate is outdated and auto-bump
  # Uses crates.io API to get latest version, with proper semver comparison
  # If outdated and bumpScript is provided, runs the script to update
  #
  # Parameters:
  #   name: crate name on crates.io
  #   currentVersion: current version string (X.Y.Z)
  #   bumpScript: path to bump_crate.rs script (optional)
  #   mode: "binstall" or "source" (default: "binstall")
  #   versionVarPostfix: postfix for version variable name (default: "Version")
  checkCrateVersion = { name, currentVersion, bumpScript ? null, mode ? "binstall", versionVarPostfix ? "Version" }: ''
    _check_crate_${builtins.replaceStrings ["-"] ["_"] name}() {
      local latest
      latest=$(curl -sf "https://crates.io/api/v1/crates/${name}" 2>/dev/null | \
        grep -o '"newest_version":"[^"]*"' | head -1 | cut -d'"' -f4)
      if [ -n "$latest" ]; then
        # Parse semver components (handles X.Y.Z, ignores pre-release suffixes)
        IFS='.-' read -r cur_major cur_minor cur_patch _ <<< "${currentVersion}"
        IFS='.-' read -r lat_major lat_minor lat_patch _ <<< "$latest"
        # Compare: latest > current means outdated
        if [ "$lat_major" -gt "$cur_major" ] 2>/dev/null || \
           ([ "$lat_major" -eq "$cur_major" ] && [ "$lat_minor" -gt "$cur_minor" ]) 2>/dev/null || \
           ([ "$lat_major" -eq "$cur_major" ] && [ "$lat_minor" -eq "$cur_minor" ] && [ "$lat_patch" -gt "$cur_patch" ]) 2>/dev/null; then
          echo "⚠️  ${name} ${currentVersion} is outdated (latest: $latest), bumping..."
          ${if bumpScript != null then ''
          if yes | ${bumpScript} --crate "${name}:${mode}" --version-var-postfix "${versionVarPostfix}"; then
            echo "✅ ${name} bumped to $latest. Please restart shell and commit changes."
          else
            echo "❌ Failed to bump ${name}"
          fi
          '' else ''
          echo "   No bump script configured"
          ''}
        fi
      fi
    }
    _check_crate_${builtins.replaceStrings ["-"] ["_"] name}
  '';
in
{
  setDefaultEnv = { name, default, is_secret ? false }:
    let
      maskedDefault = maskSecret default is_secret;
      secretFlag = if is_secret then "true" else "false";
    in
    ''
      ${maskSh}
      if [ -z "''\${${name}}" ]; then
        export ${name}="${default}"
        echo "⚠️  [WARN] Default used for ${name} = ${maskedDefault}"
      else
        __val="''\${${name}}"
        __disp="$(_mask "$__val" "${secretFlag}")"
        echo "ℹ️  [INFO] ${name} is set: ''\${__disp}"
      fi
    '';

  requireEnv = { name, is_secret ? false }:
    let
      secretFlag = if is_secret then "true" else "false";
    in
    ''
      ${maskSh}
      if [ -z "''\${${name}}" ]; then
        echo "❌ [ERROR] Required env ${name} is missing"
        exit 1
      else
        __val="''\${${name}}"
        __disp="$(_mask "$__val" "${secretFlag}")"
        echo "✅ [OK] Required env ${name} is present: ''\${__disp}"
      fi
    '';

  inherit checkCrateVersion optionalDefaults;

  # Combine multiple v-utils modules into a single shell configuration
  # Extracts enabledPackages and shellHook from each module and combines them
  #
  # Usage:
  #   combined = v-utils.utils.combineModules [ rs github readme ];
  #   devShells.default = pkgs.mkShell {
  #     packages = combined.enabledPackages;
  #     shellHook = combined.shellHook;
  #   };
  #
  # Each module should have optional `enabledPackages` (list) and `shellHook` (string) attributes.
  # Missing attributes are treated as empty.
  combineModules = modules:
    let
      getPackages = m: m.enabledPackages or [];
      getHook = m: m.shellHook or "";
    in
    {
      enabledPackages = builtins.concatLists (map getPackages modules);
      shellHook = builtins.concatStringsSep "\n" (builtins.filter (h: h != "") (map getHook modules));
    };
}
