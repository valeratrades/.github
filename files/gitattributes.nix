{ pkgs, lfs ? null }:
let
  # All file extensions that should be handled by LFS
  lfsPatterns = {
    audio = [
      "*.mp3"
      "*.flac"
      "*.wav"
      "*.ogg"
      "*.m4a"
      "*.aac"
      "*.opus"
      "*.wma"
    ];
    images = [
      "*.jpg"
      "*.jpeg"
      "*.png"
      "*.gif"
      "*.bmp"
      "*.tiff"
      "*.webp"
      "*.svg"
    ];
    documents = [
      "*.pdf"
    ];
  };

  allPatterns = lfsPatterns.audio ++ lfsPatterns.images ++ lfsPatterns.documents;

  # Generate a single line for a pattern
  # enable = true: add LFS tracking
  # enable = false: explicitly disable LFS tracking
  mkLfsLine = enable: pattern:
    if enable
    then "${pattern} filter=lfs diff=lfs merge=lfs -text"
    else "${pattern} -filter -diff -merge text";

  # Generate a section with a comment header
  mkSection = enable: name: patterns:
    let
      lines = map (mkLfsLine enable) patterns;
    in
    ''
      # ${name}
      ${builtins.concatStringsSep "\n" lines}
    '';

  # Generate all LFS-related content
  mkLfsContent = enable:
    builtins.concatStringsSep "\n" [
      (mkSection enable "Audio formats" lfsPatterns.audio)
      (mkSection enable "Image formats" lfsPatterns.images)
      (mkSection enable "Documents" lfsPatterns.documents)
    ];

  content =
    if lfs == true then mkLfsContent true
    else if lfs == false then mkLfsContent false
    else "";
in
pkgs.writeText "gitattributes" content
