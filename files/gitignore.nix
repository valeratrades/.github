{ pkgs, langs }: 
let
  gitignore = {
    shared = pkgs.runCommand "shared-gitignore" {} ''cat ${./gitignore/.gitignore} > $out'';
    rs = pkgs.runCommand "rs-gitignore" {} ''cat ${./gitignore/rs.gitignore} > $out'';
    go = pkgs.runCommand "go-gitignore" {} ''cat ${./gitignore/go.gitignore} > $out'';
    py = pkgs.runCommand "py-gitignore" {} ''cat ${./gitignore/py.gitignore} > $out'';
  };
in
  builtins.concatStringsSep "\n" (map (builtins.trace lang lang: gitignore.${lang}) (["shared"] ++ langs))
