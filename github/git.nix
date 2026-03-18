{ pkgs, labelArgs, cargoNightly, gitOpsScript }:
pkgs.writeShellScriptBin "git_ops" ''
  if [ "$1" = "sync-labels" ]; then
    exec ${cargoNightly} -Zscript -q ${gitOpsScript} "$@" ${labelArgs}
  else
    exec ${cargoNightly} -Zscript -q ${gitOpsScript} "$@"
  fi
''
