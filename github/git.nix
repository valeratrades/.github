{ pkgs, labelArgs, gitOpsScript }:
pkgs.writeShellScriptBin "git_ops" ''
  if [ "$1" = "sync-labels" ]; then
    exec ${gitOpsScript} "$@" ${labelArgs}
  else
    exec ${gitOpsScript} "$@"
  fi
''
