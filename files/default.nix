{ pkgs, ... }: 
let
  gitignore = {
    shared = ./gitignore/.gitignore;
    rs = ./gitignore/rs.gitignore;
    go = ./gitignore/go.gitignore;
    py = ./gitignore/py.gitignore;
  };
  
  combineGitignore = names:
    let
      # Always include shared, then add the requested files
      allNames = [ "shared" ] ++ names;
      # Concatenate all the gitignore files with newlines between them
      combined = builtins.concatStringsSep "\n" (map (name: builtins.readFile gitignore.${name}) allNames);
    in
    pkgs.runCommand "combined-gitignore" {} ''
      cat > $out <<'EOF'
${combined}
EOF'';
in
{
  description = "Project conf files";
  licenses = {
    blue_oak = ./licenses/blue_oak.md;
  };
  rust = {
    rustfmt = ./rust/rustfmt.nix;
    deny = ./rust/deny.nix;
    toolchain = ./rust/toolchain.nix;
    config = ./rust/config.nix;
  };
  
  inherit gitignore combineGitignore;
}
