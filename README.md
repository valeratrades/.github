# v-utils
<br>
[<img alt="ci errors" src="https://img.shields.io/github/actions/workflow/status/valeratrades/v-utils/errors.yml?branch=master&style=for-the-badge&style=flat-square&label=errors&labelColor=420d09" height="20">](https://github.com/valeratrades/v-utils/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->
[<img alt="ci warnings" src="https://img.shields.io/github/actions/workflow/status/valeratrades/v-utils/warnings.yml?branch=master&style=for-the-badge&style=flat-square&label=warnings&labelColor=d16002" height="20">](https://github.com/valeratrades/v-utils/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->

Collection of reusable Nix components for project configuration.

## Modules

### rs
Rust project configuration combining rustfmt, cargo config, and build.rs generation.
- Cranelift backend support
- cargo-deny integration
- [tracey](https://github.com/bearcove/tracey) spec coverage
- [codestyle](https://crates.io/crates/codestyle) linting

### github
GitHub integration: workflows, git hooks, gitignore, and label sync.
- Pre-commit hooks with treefmt
- CI workflow generation (errors, warnings, other)
- Automatic gitignore based on project languages

### files
File templates: rustfmt.toml, cargo config, deny.toml, treefmt, gitignore.

### readme-fw
README generation framework from `.readme_assets/` directory.
- Supports `.md` and `.typ` sources
- Badge generation (msrv, crates.io, docs.rs, loc, ci)
- License file management

## Usage
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

## Bundled Tools

The `rs` module bundles these tools from crates.io:
- **tracey** - spec coverage measurement
- **codestyle** - code style linting and auto-formatting

Version checks run on shell entry in this repo to detect when updates are needed.


<br>

<sup>
	This repository follows <a href="https://github.com/valeratrades/.github/tree/master/best_practices">my best practices</a> and <a href="https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md">Tiger Style</a> (except "proper capitalization for acronyms": (VsrState, not VSRState) and formatting).
</sup>

#### License

<sup>
	Licensed under <a href="LICENSE">Blue Oak 1.0.0</a>
</sup>

<br>

<sub>
	Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this crate by you, as defined in the Apache-2.0 license, shall
be licensed as above, without any additional terms or conditions.
</sub>

