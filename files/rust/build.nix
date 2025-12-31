{ pkgs, log_directives ? true, git_version ? true }:
let
  trimEnd = pkgs.lib.strings.trimWith { end = true; };
  git_version_code = trimEnd (builtins.readFile ./build/git_version.rs);
  log_directives_code = trimEnd (builtins.readFile ./build/log_directives.rs);

  needs_command = git_version;
  use_statement = if needs_command then "use std::process::Command;\n\n" else "";

  body_parts = (if git_version then [ git_version_code ] else [])
             ++ (if log_directives then [ log_directives_code ] else []);
  body = builtins.concatStringsSep "\n\n" body_parts;
in
pkgs.writeText "build.rs" ''
${use_statement}fn main() {
${body}
}
''
