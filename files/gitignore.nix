{ pkgs, langs }: 
let
  gitignore = {
    shared = (builtins.readFile ./gitignore/.gitignore);
    rs = (builtins.readFile ./gitignore/rs.gitignore);
    go = (builtins.readFile ./gitignore/go.gitignore);
    py = (builtins.readFile ./gitignore/py.gitignore);
  };

in {
	gitignore = builtins.trace "${gitignore.rs}" builtins.concatStringsSep "\n" (lang: gitignore.${lang}) [ "shared"] ++ langs;
	
}

