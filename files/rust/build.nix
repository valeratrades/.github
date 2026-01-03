{ pkgs, modules ? [ "git_version" "log_directives" ] }:
let
  trimEnd = pkgs.lib.strings.trimWith { end = true; };

  # Check if a module is enabled (handles both string and attrset forms)
  isModule = name: m:
    if builtins.isString m then m == name
    else if builtins.isAttrs m then builtins.hasAttr name m
    else false;

  hasModule = name: builtins.any (isModule name) modules;

  # Get deprecate config if specified
  # Supports: "deprecate" (string) or { deprecate = { by_version = "..."; force = true; }; }
  getDeprecateConfig =
    let
      isDeprecateString = m: builtins.isString m && m == "deprecate";
      isDeprecateAttr = m: builtins.isAttrs m && builtins.hasAttr "deprecate" m;
      deprecateModules = builtins.filter (m: isDeprecateString m || isDeprecateAttr m) modules;
    in
    if deprecateModules == [] then null
    else
      let m = builtins.head deprecateModules;
      in if isDeprecateString m then { by_version = null; force = false; }
      else { by_version = m.deprecate.by_version or null; force = m.deprecate.force or false; };

  deprecateConfig = getDeprecateConfig;
  has_git_version = hasModule "git_version";
  has_log_directives = hasModule "log_directives";
  has_deprecate = deprecateConfig != null;

  # Module code snippets (read lazily based on usage)
  git_version_code = trimEnd (builtins.readFile ./build/git_version.rs);
  log_directives_code = trimEnd (builtins.readFile ./build/log_directives.rs);
  deprecate_code = if has_deprecate then trimEnd (builtins.readFile ./build/deprecate.rs) else "";

  # Generate constants for deprecate module
  deprecate_const = if has_deprecate then
    let
      byVersion = if deprecateConfig.by_version != null
        then "Some(\"${deprecateConfig.by_version}\")"
        else "None";
      force = if deprecateConfig.force then "true" else "false";
    in ''
const DEPRECATE_BY_VERSION: Option<&str> = ${byVersion};
const DEPRECATE_FORCE: bool = ${force};

''
  else "";

  needs_command = has_git_version;
  use_statement = if needs_command then "use std::process::Command;\n\n" else "";

  body_parts = (if has_git_version then [ git_version_code ] else [])
             ++ (if has_log_directives then [ log_directives_code ] else [])
             ++ (if has_deprecate then [ deprecate_code ] else []);
  body = builtins.concatStringsSep "\n\n" body_parts;

  # deprecate.rs already includes closing brace for main() and helper functions after it
  # other modules are just code snippets that go inside main()
  closing_brace = if has_deprecate then "" else "\n}";
in
pkgs.writeText "build.rs" ''
${use_statement}${deprecate_const}fn main() {
${body}${closing_brace}
''
