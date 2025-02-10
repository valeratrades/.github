{ pkgs, langs }: 
let
  gitignore = {
    shared = ./gitignore/.gitignore;
    rs = ./gitignore/rs.gitignore;
    go = ./gitignore/go.gitignore;
    py = ./gitignore/py.gitignore;
  };
in
  pkgs.runCommand "combined-gitignore" {} ''
    {
      ${builtins.concatStringsSep "\n" (map (lang: "cat ${gitignore.${lang}}") (["shared"] ++ langs))}
    } > $out
  ''
