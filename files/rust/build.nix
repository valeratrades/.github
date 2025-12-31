{ pkgs, log_directives ? true, git_version ? true, deprecate ? {} }:
let
  trimEnd = pkgs.lib.strings.trimWith { end = true; };
  git_version_code = trimEnd (builtins.readFile ./build/git_version.rs);
  log_directives_code = trimEnd (builtins.readFile ./build/log_directives.rs);
  deprecate_helpers_code = trimEnd (builtins.readFile ./build/deprecate_helpers.rs);
  deprecate_code = trimEnd (builtins.readFile ./build/deprecate.rs);

  has_deprecations = deprecate != {};

  # Generate the DEPRECATIONS constant from the attrset
  # Format: { "v1.0" = [ "old_func" ]; "1.2.3" = [ "another_func" "yet_another" ]; }
  # Becomes: const DEPRECATIONS: &[(&str, &[&str])] = &[("v1.0", &["old_func"]), ...];
  deprecations_entries = builtins.attrNames deprecate;
  formatFunctions = funcs: "&[${builtins.concatStringsSep ", " (map (f: "\"${f}\"") funcs)}]";
  formatEntry = version: "(\"${version}\", ${formatFunctions deprecate.${version}})";
  deprecations_const = if has_deprecations then
    "const DEPRECATIONS: &[(&str, &[&str])] = &[${builtins.concatStringsSep ", " (map formatEntry deprecations_entries)}];\n\n"
  else "";

  needs_command = git_version;
  use_statement = if needs_command then "use std::process::Command;\n\n" else "";

  helpers = if has_deprecations then deprecate_helpers_code + "\n\n" else "";

  body_parts = (if git_version then [ git_version_code ] else [])
             ++ (if log_directives then [ log_directives_code ] else [])
             ++ (if has_deprecations then [ deprecate_code ] else []);
  body = builtins.concatStringsSep "\n\n" body_parts;
in
pkgs.writeText "build.rs" ''
${use_statement}${deprecations_const}${helpers}fn main() {
${body}
}
''
