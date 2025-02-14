{ pkgs, prj_name, last-supported-version }:
let
  loc = builtins.fromJSON (builtins.readFile (pkgs.runCommand "tokei-output" {
    nativeBuildInputs = [ pkgs.tokei pkgs.jq ];
  } ''
    cd ${./.}
    tokei --output json | jq '.Total.code' > $out
  ''));

  badges = {
    msrv = ''![Minimum Supported Rust Version](https://img.shields.io/badge/${last-supported-version}+-ab6000.svg)'';
    
    crates_io = ''[<img alt="crates.io" src="https://img.shields.io/crates/v/${prj_name}.svg?color=fc8d62&logo=rust" height="20" style=flat-square>](https://crates.io/crates/${prj_name})'';
    
    docs_rs = ''[<img alt="docs.rs" src="https://img.shields.io/badge/docs.rs-66c2a5?style=for-the-badge&labelColor=555555&logo=docs.rs&style=flat-square" height="20">](https://docs.rs/${prj_name})'';
    
    loc = ''![Lines Of Code](https://img.shields.io/badge/LoC-${toString loc}-lightblue)'';
    
    ci = ''<br>
[<img alt="ci errors" src="https://img.shields.io/github/actions/workflow/status/valeratrades/${prj_name}/errors.yml?branch=master&style=for-the-badge&style=flat-square&label=errors&labelColor=420d09" height="20">](https://github.com/valeratrades/${prj_name}/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->
[<img alt="ci warnings" src="https://img.shields.io/github/actions/workflow/status/valeratrades/${prj_name}/warnings.yml?branch=master&style=for-the-badge&style=flat-square&label=warnings&labelColor=d16002" height="20">](https://github.com/valeratrades/${prj_name}/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->'';
  };
  combineBadges = names: 
    let
      header = "# ${prj_name}";
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
