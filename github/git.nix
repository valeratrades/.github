{ pkgs, labelArgs, gitOpsScript }:
pkgs.writeShellScriptBin "git_ops" ''
  if [ "$1" = "sync-labels" ]; then
    eval "exec ${gitOpsScript} \"\$@\" ${labelArgs}"
  else
    exec ${gitOpsScript} "$@"
  fi
''
