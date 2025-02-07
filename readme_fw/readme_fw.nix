/* # Nix Readme Framework
Generates a README.md with configurable badges and sections.

Type: Function
Args:
  - pkgs: Package set with lib and runCommand
  - prj_name: Project name (string)
  - loc: Lines of code (string | int)
  - license_defs: List of license definitions
  - badgeList: List of badge names to include

Example:
```nix
let
  license = [
    { name = "blue_oak"; out_path = "LICENSE"; }
    { name = "mit license"; out_path = "LICENSE-MIT"; }
    { name = "apache license"; out_path = "LICENSE-APACHE"; }
  ];
in
(import ./readme_fw.nix) {
  inherit pkgs;
  prj_name = "my_prj";
  loc = "500";
  inherit licenses;
  badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ];
}
```
*/
{ pkgs, prj_name, loc, licenses, badges, ... }:

# Validate inputs
assert builtins.isAttrs pkgs && builtins.hasAttr "lib" pkgs && builtins.hasAttr "runCommand" pkgs;
assert builtins.isString prj_name && prj_name != "";
assert builtins.isString loc || builtins.isInt loc;
assert builtins.isList licenses && licenses != [];
assert builtins.all (item: 
  builtins.isAttrs item && 
  builtins.hasAttr "name" item && builtins.isString item.name && item.name != "" &&
  builtins.hasAttr "out_path" item && builtins.isString item.out_path && item.out_path != ""
) licenses;
assert builtins.isList badges && badges != [];
assert builtins.all builtins.isString badges;
# Verify that all badge names are valid
assert builtins.all (name: builtins.hasAttr name (import ./badges.nix { inherit pkgs prj_name loc; }).badges) badges;

let
	badgeModule = import ./badges.nix { inherit pkgs prj_name loc; };
  badges_out = badgeModule.combineBadges badges;

	description_out = let
		descriptionPath = ./.readme_assets/description.md;
		md = if builtins.pathExists descriptionPath
		then pkgs.lib.removeSuffix "\n" (builtins.readFile descriptionPath)
			else builtins.trace "WARNING: ${toString descriptionPath} is missing" "TODO";
		in
		pkgs.runCommand "" {} '' cat > $out <<'EOF'${md}'';
	
	installation_out = let
		installPath = ./.readme_assets/installation.sh;
		sh = if builtins.pathExists installPath
		then pkgs.lib.removeSuffix "\n" (builtins.readFile installPath)
      else builtins.trace "WARNING: ${toString installPath} is missing" "TODO";
		in
		pkgs.runCommand "" {} '' cat > $out <<'EOF'
<!-- markdownlint-disable -->
<details>
  <summary>
    <h2>Installation</h2>
  </summary>
	<pre>
		<code class="language-sh">
${sh}
		</code></pre>
</details>
<!-- markdownlint-restore -->'';

	usage_out = let
		usagePath = ./.readme_assets/usage.md;
		md = if builtins.pathExists usagePath
		then pkgs.lib.removeSuffix "\n" (builtins.readFile usagePath)
			else builtins.trace "WARNING: ${toString usagePath} is missing" "TODO";
		in
		pkgs.runCommand "" {} '' cat > $out <<'EOF'
## Usage
${md}
		'';

	best_practices_out = pkgs.runCommand "" {} ''
		cat > $out <<'EOF'
<br>

<sup>
	This repository follows <a href="https://github.com/valeratrades/.github/tree/master/best_practices">my best practices</a> and <a href="https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md">Tiger Style</a> (except "proper capitalization for acronyms": (VsrState, not VSRState) and formatting).
</sup>
	'';

		otherPath = ./.readme_assets/other.md;
  other_out = 
    if builtins.pathExists otherPath 
    then "\n" + builtins.readFile (pkgs.runCommand "" {} ''
      cat > $out <<'EOF'
${pkgs.lib.removeSuffix "\n" (builtins.readFile otherPath)}
EOF'')
    else ""; # `other` is fully optional, so take care not to add newlines if it's missing

	licenses_out = let
		licenseText = if builtins.length licenses == 1 
			then ''Licensed under <a href="${(builtins.head licenses).out_path}">${(builtins.head licenses).name}</a>''
		else "Licensed under either of <a href=\"${(builtins.head licenses).out_path}\">${(builtins.head licenses).name}</a> " + 
			(builtins.concatStringsSep " " 
				(builtins.map (l: ''OR <a href="${l.out_path}">${l.name}</a>'') (builtins.tail licenses))) +
			" at your option.";
		in
		pkgs.runCommand "readme_fw/licenses.md" {} ''
		cat > $out <<EOF
#### License

<sup>
	${licenseText}
</sup>

<br>

<sub>
	Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this crate by you, as defined in the Apache-2.0 license, shall
be licensed as above, without any additional terms or conditions.
</sub>
	'';
	in {
	combined = pkgs.runCommand "README.md" {} ''
  cat > $out <<'EOF'
${builtins.readFile badges_out}
${builtins.readFile description_out}
${builtins.readFile installation_out}
${builtins.readFile usage_out}${other_out}
${builtins.readFile best_practices_out}
${builtins.readFile best_practices_out}
${builtins.readFile licenses_out}
EOF
'';
}
