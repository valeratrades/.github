{ pkgs, modules ? [ "git_version" "log_directives" ] }:
let
  trimEnd = pkgs.lib.strings.trimWith { end = true; };

  # Check if a module is enabled (handles both string and attrset forms)
  isModule = name: m:
    if builtins.isString m then m == name
    else if builtins.isAttrs m then builtins.hasAttr name m
    else false;

  hasModule = name: builtins.any (isModule name) modules;

  # Get deprecate version if specified
  getDeprecateVersion =
    let
      deprecateModules = builtins.filter (m: builtins.isAttrs m && builtins.hasAttr "deprecate" m) modules;
    in
    if deprecateModules == [] then null
    else (builtins.head deprecateModules).deprecate;

  deprecateVersion = getDeprecateVersion;
  has_git_version = hasModule "git_version";
  has_log_directives = hasModule "log_directives";
  has_deprecate = deprecateVersion != null;

  # Module code snippets (read lazily based on usage)
  git_version_code = trimEnd (builtins.readFile ./build/git_version.rs);
  log_directives_code = trimEnd (builtins.readFile ./build/log_directives.rs);
  deprecate_code = if has_deprecate then trimEnd (builtins.readFile ./build/deprecate.rs) else "";

  # Generate the DEPRECATE_AT_VERSION constant if needed
  deprecate_const = if has_deprecate then
    "const DEPRECATE_AT_VERSION: &str = \"${deprecateVersion}\";\n\n"
  else "";

  needs_command = has_git_version;
  use_statement = if needs_command then "use std::process::Command;\n\n" else "";

  body_parts = (if has_git_version then [ git_version_code ] else [])
             ++ (if has_log_directives then [ log_directives_code ] else [])
             ++ (if has_deprecate then [ deprecate_code ] else []);
  body = builtins.concatStringsSep "\n\n" body_parts;
in
pkgs.writeText "build.rs" ''
${use_statement}${deprecate_const}fn main() {
${body}
}
''
