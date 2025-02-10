{ pkgs, langs }: 
let
  gitignore = {
    shared = builtins.readFile ./gitignore/.gitignore;
    rs = builtins.readFile ./gitignore/rs.gitignore;
    go = builtins.readFile ./gitignore/go.gitignore;
    py = builtins.readFile ./gitignore/py.gitignore;
  };

  combineGitignore = selected_langs: 
    let
			all = [ "shared" ] ++ selected_langs;
      joined = builtins.concatStringsSep "\n" (lang: gitignore.${lang}) all;
    in
    pkgs.runCommand "" {} ''
      cat > $out <<'EOF'
${joined}
EOF'';

in {
	gitignore = combineGitignore langs;
}

