{ pkgs }:
let
  # Helper function to create a target entry
  mkTarget = triple: { inherit triple; };
in
(pkgs.formats.toml { }).generate "deny.toml" {
  # `cargo deny` is only intended to run these targets for this project
  targets = [
    (mkTarget "aarch64-unknown-linux-gnu")
    (mkTarget "x86_64-unknown-linux-gnu")
    (mkTarget "x86_64-unknown-linux-musl")
  ];

  # Considered when running `cargo deny check advisories`
  # https://embarkstudios.github.io/cargo-deny/checks/advisories/cfg.html
  advisories = {
    notice = "deny";
    unmaintained = "warn";
    unsound = "deny";
    vulnerability = "deny";
    yanked = "deny";
    ignore = [];
  };

  # Considered when running `cargo deny check licenses`
  # https://embarkstudios.github.io/cargo-deny/checks/licenses/cfg.html
  licenses = {
    allow-osi-fsf-free = "neither";
    copyleft = "deny";
    unlicensed = "deny";
    private = { ignore = true; };
    confidence-threshold = 0.925;
    allow = [
				"Apache-2.0 WITH LLVM-exception" # https://spdx.org/licenses/LLVM-exception.html
				"Apache-2.0"                     # https://spdx.org/licenses/Apache-2.0.html
				"BSD-3-Clause"                   # https://spdx.org/licenses/BSD-3-Clause.html
				"BlueOak-1.0.0"                 # https://blueoakcouncil.org/license/1.0.0
				"CC0-1.0"                       # https://spdx.org/licenses/CC0-1.0.html
				"ISC"                           # https://spdx.org/licenses/ISC.html
				"MIT"                           # https://spdx.org/licenses/MIT.html
				"MPL-2.0"                       # https://spdx.org/licenses/MPL-2.0.html
				"Unicode-DFS-2016"              # https://spdx.org/licenses/Unicode-DFS-2016.html
				"Unlicense"                     # https://spdx.org/licenses/Unlicense.html
    ];
    exceptions = [];
  };

  # Considered when running `cargo deny check bans`
  # https://embarkstudios.github.io/cargo-deny/checks/bans/cfg.html
  bans = {
    multiple-versions = "warn";
    wildcards = "allow";
    deny = [];
    skip = [];
    skip-tree = [];
  };

  # Considered when running `cargo deny check sources`
  # https://embarkstudios.github.io/cargo-deny/checks/sources/cfg.html
  sources = {
    unknown-registry = "deny";
    unknown-git = "deny";
    allow-org.github = ["valeratrades"];
  };
}
