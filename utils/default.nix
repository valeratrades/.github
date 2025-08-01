let
  maskSecret = s: isSecret:
    if !isSecret then s else
    let
      len = builtins.stringLength s;
    in if len < 8 then "[REDACTED]"
       else (builtins.substring 0 2 s) + ".." + (builtins.substring (len - 2) 2 s);
in
{
  setDefaultEnv = { name, default, is_secret ? false }:
    let
      maskedDefault = maskSecret default is_secret;
    in
    ''
      if [ -z "''\${${name}}" ]; then
        export ${name}="${default}"
        echo "⚠️  [WARN] Default used for ${name} = ${maskedDefault}"
      else
        echo "ℹ️  [INFO] ${name} is set: ${maskSecret "''\${${name}}" is_secret}"
      fi
    '';

  requireEnv = { name, is_secret ? false }:
    ''
      if [ -z "''\${${name}}" ]; then
        echo "❌ [ERROR] Required env ${name} is missing"
        exit 1
      else
        echo "✅ [OK] Required env ${name} is present: ${maskSecret "''\${${name}}" is_secret}"
      fi
    '';
}
