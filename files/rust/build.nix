{ pkgs, modules ? [ "git_version" "log_directives" ] }:
let
  # Check if a module is enabled (handles both string and attrset forms)
  isModule = name: m:
    if builtins.isString m then m == name
    else if builtins.isAttrs m then builtins.hasAttr name m
    else false;

  hasModule = name: builtins.any (isModule name) modules;

  # Get deprecate config if specified
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

  # Module code (each defines a function with the same name as the module)
  git_version_code = builtins.readFile ./build/git_version.rs;
  log_directives_code = builtins.readFile ./build/log_directives.rs;
  deprecate_code = builtins.readFile ./build/deprecate.rs;

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

  # Collect module codes
  module_codes = (if has_git_version then [ git_version_code ] else [])
               ++ (if has_log_directives then [ log_directives_code ] else [])
               ++ (if has_deprecate then [ deprecate_code ] else []);

  # Collect function calls for main()
  module_calls = (if has_git_version then [ "git_version();" ] else [])
               ++ (if has_log_directives then [ "log_directives();" ] else [])
               ++ (if has_deprecate then [ "deprecate();" ] else []);

  modules_body = builtins.concatStringsSep "\n" module_codes;
  main_calls = builtins.concatStringsSep "\n\t" module_calls;
in
pkgs.writeText "build.rs" ''
${deprecate_const}fn main() {
	${main_calls}
}

${modules_body}
''
