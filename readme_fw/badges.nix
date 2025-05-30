{
  pkgs,
  rootDir,
  pname,
  lastSupportedVersion,
}: let
  loc = builtins.fromJSON (builtins.readFile (pkgs.runCommand "tokei-output" {
      nativeBuildInputs = [pkgs.tokei pkgs.jq];
    } ''
      cd ${rootDir}
      tokei --output json | jq '.Total.code' > $out
    ''));

  badges = {
    msrv = ''![Minimum Supported Rust Version](https://img.shields.io/badge/${lastSupportedVersion}+-ab6000.svg)'';

    crates_io = ''[<img alt="crates.io" src="https://img.shields.io/crates/v/${pname}.svg?color=fc8d62&logo=rust" height="20" style=flat-square>](https://crates.io/crates/${pname})'';

    docs_rs = ''[<img alt="docs.rs" src="https://img.shields.io/badge/docs.rs-66c2a5?style=for-the-badge&labelColor=555555&logo=docs.rs&style=flat-square" height="20">](https://docs.rs/${pname})'';

    loc = ''![Lines Of Code](https://img.shields.io/badge/LoC-${toString loc}-lightblue)'';

    # note that it is possible to remove all references to `master` and have it automatically use the current branch. But that would require running them on `on.push.branches: [**]`.
    ci = ''      <br>
      [<img alt="ci errors" src="https://img.shields.io/github/actions/workflow/status/valeratrades/${pname}/errors.yml?branch=master&style=for-the-badge&style=flat-square&label=errors&labelColor=420d09" height="20">](https://github.com/valeratrades/${pname}/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->
      [<img alt="ci warnings" src="https://img.shields.io/github/actions/workflow/status/valeratrades/${pname}/warnings.yml?branch=master&style=for-the-badge&style=flat-square&label=warnings&labelColor=d16002" height="20">](https://github.com/valeratrades/${pname}/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->'';
  };
  combineBadges = names: let
    header = "# ${pname}";
    mainBadges = builtins.concatStringsSep "\n" (map (name: badges.${name}) names);
  in
    pkgs.runCommand "" {} ''
            cat > $out <<'EOF'
      ${header}
      ${mainBadges}
      EOF'';
in {
  inherit combineBadges;
}
