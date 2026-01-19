# Supports both `.md` and `.typ` file sources
# When `defaults = true` (or `default = true`), `licenses` defaults to Blue Oak 1.0.0.
# Note: `rootDir` cannot have a default - paths resolve at parse time, so caller must always pass `rootDir = ./.;`
#
# licenses: list of { outPath?, license }
#   - outPath: (optional, defaults to "LICENSE") path in the repo where the license will be copied
#   - license: attrset from files.licenses.* with { name, path }
args@{
  pkgs,
  rootDir,
  pname,
  badges,
  lastSupportedVersion,
  defaults ? false,
  default ? defaults,
  licenses ? null,
  gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb",
}:

let
  defaultLicense = { name = "Blue Oak 1.0.0"; path = ../files/licenses/blue_oak.md; };
  licensesRaw = if licenses != null then licenses else
    assert default || throw "licenses is required when defaults = false";
    [{ license = defaultLicense; }];

  # Normalize licenses: add default outPath if missing
  licensesNormalized = builtins.map (l: l // { outPath = l.outPath or "LICENSE"; }) licensesRaw;

  # Check for duplicate outPaths
  outPaths = builtins.map (l: l.outPath) licensesNormalized;
  uniqueOutPaths = pkgs.lib.unique outPaths;
  hasDuplicates = builtins.length outPaths != builtins.length uniqueOutPaths;
in

# Validate inputs
assert builtins.isAttrs pkgs && builtins.hasAttr "lib" pkgs && builtins.hasAttr "runCommand" pkgs;
assert builtins.isPath rootDir;
assert builtins.isString pname && pname != "";
assert builtins.isList licensesNormalized && licensesNormalized != [ ];
assert builtins.all (
  item: builtins.isAttrs item
    && builtins.hasAttr "outPath" item && builtins.isString item.outPath && item.outPath != ""
    && builtins.hasAttr "license" item && builtins.isAttrs item.license
    && builtins.hasAttr "name" item.license && builtins.isString item.license.name
    && builtins.hasAttr "path" item.license
) licensesNormalized;
assert !hasDuplicates || throw "licenses have duplicate outPaths: ${builtins.concatStringsSep ", " outPaths}";
assert builtins.isList badges && badges != [ ];
assert builtins.all builtins.isString badges;

let
  licenses = licensesNormalized;
  rootStr = pkgs.lib.removeSuffix "/" (toString rootDir);

  #Q: theoretically could have this thing right here count the LoC itself. Could be cleaner.
  badgeModule = builtins.trace "DEBUG: loading badges" import ./badges.nix {
    inherit
      pkgs
      pname
      lastSupportedVersion
      rootDir
      gistId
      ;
  };

  initLocGistScript = ./init_loc_gist.rs;
  init_loc_gist = pkgs.writeShellScriptBin "init-loc-gist" ''
    exec ${initLocGistScript} --pname "${pname}" --gist-id "${gistId}" "$@"
  '';
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
      demoteHeaders ? true, # Whether to demote markdown headers by one level
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
          isTyp = pkgs.lib.hasSuffix ".typ" singlePath;
          isMd = pkgs.lib.hasSuffix ".md" singlePath;

          # For .typ files, compile to markdown using pandoc (which can read typst)
          typstContent = if isTyp && exists then
            let
              typFile = builtins.path { path = fullPath; };
            in
            builtins.readFile (pkgs.runCommand "typst-to-markdown" { buildInputs = [ pkgs.pandoc ]; } ''
              pandoc -f typst -t markdown ${typFile} -o $out
            '')
          else "";

          rawContent =
            if isTyp && exists then
              typstContent
            else if exists then
              pkgs.lib.removeSuffix "\n" (builtins.readFile fullPath)
            else if optional then
              ""
            else
              builtins.trace "WARNING: ${toString fullPath} is missing" "TODO";

          contentWithPaths = if isMd && exists then
            builtins.replaceStrings
              [ "(./" "(../" "[./" "[../" ]
              [ "(./.readme_assets/" "(./" "[./.readme_assets/" "[./" ]
              rawContent
          else rawContent;

          # Demote all markdown headers by one level (# -> ##, ## -> ###, etc.)
          # Tracks whether we're inside a ``` code block to avoid demoting comments
          demoteHeadersFn = text:
            let
              lines = pkgs.lib.splitString "\n" text;
              isCodeFence = line: builtins.match "^```.*" line != null;
              processLines = builtins.foldl' (acc: line:
                let
                  inCode = if isCodeFence line then !acc.inCode else acc.inCode;
                  isHeader = builtins.match "^(#+) .*" line != null;
                  newLine = if isHeader && !acc.inCode then "#" + line else line;
                in
                { inCode = inCode; result = acc.result ++ [ newLine ]; }
              ) { inCode = false; result = []; } lines;
            in
            builtins.concatStringsSep "\n" processLines.result;

          contentWithDemotedHeaders = if demoteHeaders then demoteHeadersFn contentWithPaths else contentWithPaths;

          out = (if (exists || !optional) then (transform contentWithDemotedHeaders singlePath) + "\n" else contentWithDemotedHeaders);
        in
        out;

      # Process all matching files
      fileContents = builtins.map processSingleFile matchingPaths;

      # Combine all contents
      combinedContent = builtins.concatStringsSep "" fileContents;
    in
    if matchingFiles == [ ] && optional then "" else combinedContent;

  warning_out = processSection {
    path = ".readme_assets/warning\\.(md|typ)";
    optional = true;
    transform = (content: path: if content == "" then "" else "\n> [!WARNING]\n" + builtins.concatStringsSep " \\\n" (map (line: "> " + line) (pkgs.lib.splitString "\n" content)));
  };

  description_out = processSection {
    path = ".readme_assets/description\\.(md|typ)";
  };

  installation_out = processSection {
    path = ".readme_assets/(installation|install)(-[a-zA-Z0-9\\-]+)?\\.(sh|md|typ)";
    transform =
      content: path:
      let
        fileName = builtins.baseNameOf path;
        fileExt = builtins.elemAt (pkgs.lib.splitString "." fileName) 1;
        isMd = fileExt == "md";
        isTyp = fileExt == "typ";

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
          if isMd || isTyp then
            content
          else
            ''```sh
${content}
```'';
      in
      ''
<!-- markdownlint-disable -->
<details>
<summary>
<h3>${headerText}</h3>
</summary>

${contentRendered}

</details>
<!-- markdownlint-restore -->'';
    optional = true;
  };

  usage_out = processSection {
    path = ".readme_assets/usage\\.(sh|md|typ)";
    transform =
      content: path:
      let
        fileName = builtins.baseNameOf path;
        fileExt = builtins.elemAt (pkgs.lib.splitString "." fileName) 1;
        isSh = fileExt == "sh";
        contentRendered = if isSh then
          ''```sh
${content}
```''
        else
          content;
      in
      ''
        ## Usage
        ${contentRendered}
      '';
  };

  # Architecture link - warns if docs/ARCHITECTURE.md doesn't exist
  architectureExists =
    let
      archPath = "${rootStr}/docs/ARCHITECTURE.md";
    in
    if builtins.pathExists archPath then
      true
    else
      builtins.trace "WARNING: docs/ARCHITECTURE.md is missing. Consider adding one, following https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html" false;

  architectureSentence = if architectureExists then
    " For project's architecture, see <a href=\"./docs/ARCHITECTURE.md\">ARCHITECTURE.md</a>."
  else
    "";

  best_practices_out = pkgs.runCommand "" { } ''
    		cat > $out <<'EOF'

    <br>

    <sup>
    	This repository follows <a href="https://github.com/valeratrades/.github/tree/master/best_practices">my best practices</a> and <a href="https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md">Tiger Style</a> (except "proper capitalization for acronyms": (VsrState, not VSRState) and formatting).${architectureSentence}
    </sup>
  '';

  other_out = processSection {
    path = ".readme_assets/other\\.(md|typ)";
    optional = true;
    demoteHeaders = false;
  };

  licenses_out =
    let
      licenseText =
        if builtins.length licenses == 1 then
          ''Licensed under <a href="${(builtins.head licenses).outPath}">${(builtins.head licenses).license.name}</a>''
        else
          "Licensed under either of <a href=\"${(builtins.head licenses).outPath}\">${(builtins.head licenses).license.name}</a> "
          + (builtins.concatStringsSep " " (builtins.map (l: ''OR <a href="${l.outPath}">${l.license.name}</a>'') (builtins.tail licenses)))
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

  readme = pkgs.runCommand "README.md" { } ''
    cat > $out <<'README_EOF'
${warning_out}${builtins.readFile badges_out}
${description_out}${installation_out}
${usage_out}${other_out}
${builtins.readFile best_practices_out}
${builtins.readFile licenses_out}
README_EOF
  '';

  shellHook =
    let
      licenseCopies = builtins.concatStringsSep "\n" (
        builtins.map (l: "cp -f ${l.license.path} ./${l.outPath}") licenses
      );
    in
    ''
      ${licenseCopies}
      cp -f ${readme} ./README.md
    '';
in
{
  inherit readme shellHook init_loc_gist;
  enabledPackages = [ init_loc_gist pkgs.tokei ];
}
