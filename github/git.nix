{ pkgs, labelArgs, gitOpsScript }:
pkgs.writeShellScriptBin "git_ops" ''
  if [ "$1" = "sync-labels" ]; then
    exec cargo -Zscript -q ${gitOpsScript} "$@" ${labelArgs}
  else
    exec cargo -Zscript -q ${gitOpsScript} "$@"
  fi
''
