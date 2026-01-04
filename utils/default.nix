let
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
  checkCrateVersion = { name, currentVersion, bumpScript ? null }: ''
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
          if ${bumpScript} ${name}; then
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

  inherit checkCrateVersion;
}
