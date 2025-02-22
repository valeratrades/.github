{ pkgs, rootDir, pname, licenses, badges, lastSupportedVersion }:

# Validate inputs
assert builtins.isAttrs pkgs && builtins.hasAttr "lib" pkgs && builtins.hasAttr "runCommand" pkgs;
assert builtins.isPath rootDir;
assert builtins.isString pname && pname != "";
assert builtins.isList licenses && licenses != [];
assert builtins.all (item: 
  builtins.isAttrs item && 
  builtins.hasAttr "name" item && builtins.isString item.name && item.name != "" &&
  builtins.hasAttr "outPath" item && builtins.isString item.outPath && item.outPath != ""
) licenses;
assert builtins.isList badges && badges != [];
assert builtins.all builtins.isString badges;

let
	rootStr = pkgs.lib.removeSuffix "/" (toString rootDir);

	#Q: theoretically could have this thing right here count the LoC itself. Could be cleaner.
	badgeModule = builtins.trace "DEBUG: loading badges" import ./badges.nix { inherit pkgs pname lastSupportedVersion rootDir; };
  badges_out = badgeModule.combineBadges badges;

	warningPath = "${rootStr}/.readme_assets/warning.md";
warning_out = 
  if builtins.pathExists warningPath 
  then "\n" + builtins.readFile (pkgs.runCommand "" {} ''
    cat > $out <<'EOF'
> [!WARNING]
${builtins.concatStringsSep " \\\n" (map (line: "> " + line) 
  (pkgs.lib.splitString "\n" 
    (pkgs.lib.removeSuffix "\n" (builtins.readFile warningPath))))}
EOF'')
  else ""; # fully optional, so take care not to add newlines if it's missing


	description_out = let
		descriptionPath = "${rootStr}/.readme_assets/description.md";
		md = if builtins.pathExists descriptionPath
		then pkgs.lib.removeSuffix "\n" (builtins.readFile descriptionPath)
			else builtins.trace "WARNING: ${toString descriptionPath} is missing" "TODO";
		in
		pkgs.runCommand "" {} '' cat > $out <<'EOF'
${md}'';
	
	installation_out = let
		installPath = "${rootStr}/.readme_assets/installation.sh";
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
		<code class="language-sh">${sh}</code></pre>
</details>
<!-- markdownlint-restore -->''; # `${sh}` is not padded with newlines, as that physically pads the rendered code block

	usage_out = let
		usagePath = "${rootStr}/.readme_assets/usage.md";
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

		otherPath = "${rootStr}/.readme_assets/other.md";
  other_out = 
    if builtins.pathExists otherPath 
    then "\n" + builtins.readFile (pkgs.runCommand "" {} ''
      cat > $out <<'EOF'
${pkgs.lib.removeSuffix "\n" (builtins.readFile otherPath)}
EOF'')
    else ""; # `other` is fully optional, so take care not to add newlines if it's missing

	licenses_out = let
		licenseText = if builtins.length licenses == 1 
			then ''Licensed under <a href="${(builtins.head licenses).outPath}">${(builtins.head licenses).name}</a>''
		else "Licensed under either of <a href=\"${(builtins.head licenses).outPath}\">${(builtins.head licenses).name}</a> " + 
			(builtins.concatStringsSep " " 
				(builtins.map (l: ''OR <a href="${l.outPath}">${l.name}</a>'') (builtins.tail licenses))) +
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
	in
	pkgs.runCommand "README.md" {} ''
  cat > $out <<'EOF'${warning_out}
${builtins.readFile badges_out}
${builtins.readFile description_out}
${builtins.readFile installation_out}
${builtins.readFile usage_out}${other_out}
${builtins.readFile best_practices_out}
${builtins.readFile licenses_out}
EOF
''
