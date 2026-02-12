{ pkgs, labelArgs, gitOpsScript }:
pkgs.writeShellScriptBin "git_ops" ''
  if [ "$1" = "sync-labels" ]; then
    eval "exec cargo -Zscript -q ${gitOpsScript} \"\$@\" ${labelArgs}"
  else
    exec cargo -Zscript -q ${gitOpsScript} "$@"
  fi
''
