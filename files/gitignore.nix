{ pkgs, langs }: 
let
  gitignore = {
    shared = ./gitignore/.gitignore;
    rs = ./gitignore/rs.gitignore;
    go = ./gitignore/go.gitignore;
    py = ./gitignore/py.gitignore;
  };

  combineGitignore = selected_langs: 
    let
			all = [ "shared" ] ++ selected_langs;
      joined = builtins.concatStringsSep "\n" (lang: (builtins.readFile gitignore.${lang})) all;
    in
    pkgs.runCommand "" {} ''
      cat > $out <<'EOF'
${joined}
EOF'';

in {
	gitignore = combineGitignore langs;
}

