```nix
{
  inputs.v-utils.url = "github:valeratrades/.github";

  outputs = { self, nixpkgs, v-utils, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      pname = "my-project";

      rs = v-utils.rs {
        inherit pkgs;
        tracey = true;
        style.format = true;
      };

      github = v-utils.github {
        inherit pkgs pname;
        inherit (rs) styleFormat styleAssert;
        langs = [ "rs" ];
        jobs.default = true;
      };

      readme = v-utils.readme-fw {
        inherit pkgs pname;
        rootDir = ./.;
        lastSupportedVersion = "nightly-1.86";
        defaults = true;
        badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ];
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = rs.enabledPackages ++ github.enabledPackages;
        shellHook = ''
          ${rs.shellHook}
          ${github.shellHook}
          ${readme.shellHook}
        '';
      };
    };
}
```
