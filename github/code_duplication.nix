{ pkgs, script }:
pkgs.writeShellScriptBin "code_duplication" ''
  if ! command -v qlty &>/dev/null; then
    echo "qlty is not installed. Install it with: curl https://qlty.sh | bash" >&2
    exit 1
  fi
  qlty init --no --no-upgrade-check 2>/dev/null
  exec cargo +nightly -Zscript -q ${script} "$@"
''
