{
  description = "Example usage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23e89b7da85c3640bbc2173fe04f4bd114342367";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        readme-fw = import ./.;

        pname = "readme-fw";
        readme = readme-fw {
          inherit pkgs pname;
          lastSupportedVersion = "nightly-1.86";
          rootDir = ./.;
          licenses = [
            {
              name = "Blue Oak 1.0.0";
              outPath = "LICENSE";
            }
          ];
          badges = [
            "msrv"
            "crates_io"
            "docs_rs"
            "loc"
            "ci"
          ];
        };

        # Generate GitHub Actions workflows
        workflows = import ../github/workflows/nix-parts {
          inherit pkgs;
          lastSupportedVersion = "nightly-1.86";
          jobsErrors = [ ];  # Add your error jobs here
          jobsWarnings = [ ];  # Add your warning jobs here
          jobsOther = [ "loc-badge" ];  # LOC badge updater
        };
      in
      {
        packages = {
          inherit workflows;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.typst pkgs.pandoc ];
          shellHook = ''
            cp -f ${readme} ./README.md

            # Generate workflows
            mkdir -p .github/workflows
            cp -f ${workflows.other} .github/workflows/other.yml
          '';
        };
      }
    );
}
