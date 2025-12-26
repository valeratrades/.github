{ pkgs, labelArgs, gitScript }:
{
  git_sync_labels = pkgs.writeShellScriptBin "git_sync_labels" ''
    exec ${gitScript} sync-labels ${labelArgs} "$@"
  '';
}
