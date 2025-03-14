#TODO: allow all `.md` files to be written as `.typ` instead.
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


	# Helper function to process markdown sections with standardized handling
processSection = { 
  path,           # Path to the file relative to root
  optional ? false, # Whether to warn on missing source for a section
  transform ? (content: content) # Function that transforms content (including adding any prefix/suffix)
}:
let
  fullPath = "${rootStr}/${path}";
  exists = builtins.pathExists fullPath;
  
	# Handle missing files based on `optional` flag
  rawContent = if exists
    then pkgs.lib.removeSuffix "\n" (builtins.readFile fullPath) #TODO: remove **all** trailing newlines, not just one
    else if optional
      then ""
      else builtins.trace "WARNING: ${toString fullPath} is missing" "TODO";

  # Apply path replacement automatically for markdown files //TODO: extend to support `typ` too
  contentWithPaths = if pkgs.lib.hasSuffix ".md" path && exists
    then builtins.replaceStrings ["(./"] ["(./.readme_assets/"] rawContent
    else rawContent;

  out = (transform contentWithPaths) + (if (exists || !optional) then
    "\n"
    else "");
in
    /*builtins.trace ''TRACE: ${path}: "${out}"''*/ out;


  warning_out = processSection {
  path = ".readme_assets/warning.md";
  optional = true;
  transform = (content: 
    if content == "" 
    then "" 
    else "\n> [!WARNING]\n" + 
      builtins.concatStringsSep " \\\n" (map (line: "> " + line) 
        (pkgs.lib.splitString "\n" content))
  );
};


	description_out = processSection {
		path = ".readme_assets/description.md";
	};
	
  installation_out = processSection {
    path = ".readme_assets/installation.sh";
    transform = (sh: ''
<!-- markdownlint-disable -->
<details>
  <summary>
    <h2>Installation</h2>
  </summary>
  <pre>
    <code class="language-sh">${sh}</code></pre>
</details>
<!-- markdownlint-restore -->
  ''); # `${sh}` is not padded with newlines, as that physically pads the rendered code block
		optional = true;
  };

	usage_out = processSection {
		path = ".readme_assets/usage.md";
		transform = (md: ''
## Usage
${md}
'');
	};

	best_practices_out = pkgs.runCommand "" {} ''
		cat > $out <<'EOF'

<br>

<sup>
	This repository follows <a href="https://github.com/valeratrades/.github/tree/master/best_practices">my best practices</a> and <a href="https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md">Tiger Style</a> (except "proper capitalization for acronyms": (VsrState, not VSRState) and formatting).
</sup>
'';


other_out = processSection {
  path = ".readme_assets/other.md";
  optional = true;
};

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
${description_out}
${installation_out}
${usage_out}${other_out}
${builtins.readFile best_practices_out}
${builtins.readFile licenses_out}EOF''
