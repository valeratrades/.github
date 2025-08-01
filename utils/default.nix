let
  maskSecret = s: isSecret:
    if !isSecret then s else
    let len = builtins.stringLength s;
    in if len < 8 then "[REDACTED]"
       else (builtins.substring 0 2 s) + ".." + (builtins.substring (len - 2) 2 s);

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
}
