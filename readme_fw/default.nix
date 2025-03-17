#TODO: allow all `.md` files to be written as `.typ` instead.
{
  pkgs,
  rootDir,
  pname,
  licenses,
  badges,
  lastSupportedVersion,
}:

# Validate inputs
assert builtins.isAttrs pkgs && builtins.hasAttr "lib" pkgs && builtins.hasAttr "runCommand" pkgs;
assert builtins.isPath rootDir;
assert builtins.isString pname && pname != "";
assert builtins.isList licenses && licenses != [ ];
assert builtins.all (
  item: builtins.isAttrs item && builtins.hasAttr "name" item && builtins.isString item.name && item.name != "" && builtins.hasAttr "outPath" item && builtins.isString item.outPath && item.outPath != ""
) licenses;
assert builtins.isList badges && badges != [ ];
assert builtins.all builtins.isString badges;

let
  rootStr = pkgs.lib.removeSuffix "/" (toString rootDir);

  #Q: theoretically could have this thing right here count the LoC itself. Could be cleaner.
  badgeModule = builtins.trace "DEBUG: loading badges" import ./badges.nix {
    inherit
      pkgs
      pname
      lastSupportedVersion
      rootDir
      ;
  };
  badges_out = badgeModule.combineBadges badges;

  # Helper function to process markdown sections with standardized handling
  #processSection =
  #  {
  #    path, # Path to the file relative to root
  #    optional ? false, # Whether to warn on missing source for a section
  #    transform ? (content: content), # Function that transforms content (including adding any prefix/suffix)
  #  }:
  #  let
  #    fullPath = "${rootStr}/${path}";
  #    exists = builtins.pathExists fullPath;
  #
  #    # Handle missing files based on `optional` flag
  #    rawContent =
  #      if exists then
  #        pkgs.lib.removeSuffix "\n" (builtins.readFile fullPath) # TODO: remove **all** trailing newlines, not just one
  #      else if optional then
  #        ""
  #      else
  #        builtins.trace "WARNING: ${toString fullPath} is missing" "TODO";
  #
  #    # Apply path replacement automatically for markdown files //TODO: extend to support `typ` too
  #    contentWithPaths = if pkgs.lib.hasSuffix ".md" path && exists then builtins.replaceStrings [ "(./" ] [ "(./.readme_assets/" ] rawContent else rawContent;
  #
  #    out = (if (exists || !optional) then (transform contentWithPaths) + "\n" else contentWithPaths);
  #  in
  #  # builtins.trace ''TRACE: ${path}: "${out}"''
  #  out;

  processSection =
    {
      path, # Regex pattern for file(s) relative to root
      optional ? false, # Whether to warn on missing source for a section
      transform ? (content: actualPath: content), # Function that transforms content, taking actual path
    }:
    let
      # Get directory and pattern from path
      dirPath = builtins.dirOf path;
      baseName = builtins.baseNameOf path;
      searchDir = "${rootStr}/${dirPath}";
      dirExists = builtins.pathExists searchDir;

      # List all files in the directory, filter for pattern matches
      allFiles = if dirExists then builtins.attrNames (builtins.readDir searchDir) else [ ];
      matchingFiles = builtins.filter (name: builtins.match baseName name != null) allFiles;

      # Full paths relative to root
      matchingPaths = map (name: "${dirPath}/${name}") matchingFiles;

      # Process a single file
      processSingleFile =
        singlePath:
        let
          fullPath = "${rootStr}/${singlePath}";
          exists = builtins.pathExists fullPath;

          rawContent =
            if exists then
              pkgs.lib.removeSuffix "\n" (builtins.readFile fullPath)
            else if optional then
              ""
            else
              builtins.trace "WARNING: ${toString fullPath} is missing" "TODO";

          contentWithPaths = if pkgs.lib.hasSuffix ".md" singlePath && exists then builtins.replaceStrings [ "(./" ] [ "(./.readme_assets/" ] rawContent else rawContent;

          out = (if (exists || !optional) then (transform contentWithPaths singlePath) + "\n" else contentWithPaths);
        in
        out;

      # Process all matching files
      fileContents = builtins.map processSingleFile matchingPaths;

      # Combine all contents
      combinedContent = builtins.concatStringsSep "" fileContents;
    in
    if matchingFiles == [ ] && optional then "" else combinedContent;

  warning_out = processSection {
    path = ".readme_assets/warning.md";
    optional = true;
    transform = (content: path: if content == "" then "" else "\n> [!WARNING]\n" + builtins.concatStringsSep " \\\n" (map (line: "> " + line) (pkgs.lib.splitString "\n" content)));
  };

  description_out = processSection {
    path = ".readme_assets/description.md";
  };

  installation_out = processSection {
    path = ".readme_assets/installation(-[a-zA-Z0-9\\-]+)?\\.(sh|md)";
    transform =
      content: path:
      let
        fileName = builtins.baseNameOf path;
        fileExt = builtins.elemAt (pkgs.lib.splitString "." fileName) 1;
        isMd = fileExt == "md";

        basePart = builtins.substring (builtins.stringLength "installation") (builtins.stringLength fileName - builtins.stringLength "installation" - builtins.stringLength ".${fileExt}") fileName;

        hasSuffix = pkgs.lib.hasPrefix "-" basePart;
        suffixPart = if hasSuffix then pkgs.lib.removePrefix "-" basePart else "";
        titleCaseWord = word: if builtins.stringLength word == 0 then "" else pkgs.lib.toUpper (builtins.substring 0 1 word) + builtins.substring 1 (builtins.stringLength word) word;

        formatSuffix =
          suffix:
          let
            segments = pkgs.lib.splitString "-" suffix;
            titledSegments = map titleCaseWord segments;
            concat_back = builtins.concatStringsSep " " titledSegments;
          in
          concat_back;

        headerText = if suffixPart == "" then "Installation" else "Installation: ${formatSuffix suffixPart}";
        contentRendered =
          if isMd then
            content
          else
            ''<pre><code class="language-sh">${content}</code></pre>'';
      in
      ''
        <!-- markdownlint-disable -->
        <details>
          <summary>
            <h2>${headerText}</h2>
          </summary>
        ${contentRendered}
        </details>
        <!-- markdownlint-restore -->
      '';
    optional = true;
  };

  usage_out = processSection {
    path = ".readme_assets/usage.md";
    transform = (
      content: path: ''
        ## Usage
        ${content}
      ''
    );
  };

  best_practices_out = pkgs.runCommand "" { } ''
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

  licenses_out =
    let
      licenseText =
        if builtins.length licenses == 1 then
          ''Licensed under <a href="${(builtins.head licenses).outPath}">${(builtins.head licenses).name}</a>''
        else
          "Licensed under either of <a href=\"${(builtins.head licenses).outPath}\">${(builtins.head licenses).name}</a> "
          + (builtins.concatStringsSep " " (builtins.map (l: ''OR <a href="${l.outPath}">${l.name}</a>'') (builtins.tail licenses)))
          + " at your option.";
    in
    pkgs.runCommand "readme_fw/licenses.md" { } ''
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
pkgs.runCommand "README.md" { } ''
    cat > $out <<'EOF'${warning_out}
  ${builtins.readFile badges_out}
  ${description_out}${installation_out}
  ${usage_out}${other_out}
  ${builtins.readFile best_practices_out}
  ${builtins.readFile licenses_out}EOF''
