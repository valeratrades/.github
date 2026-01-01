args@{ pkgs ? null, nixpkgs ? null, pname ? null, lastSupportedVersion ? null, jobsErrors ? [], jobsWarnings ? [], jobsOther ? [], hookPre ? {}, gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb", langs ? ["rs"], labels ? {}, preCommit ? {}, traceyCheck ? false }:

# If called with just nixpkgs (for flake description), return description attribute
if nixpkgs != null && pkgs == null then {
  description = ''
GitHub integration module combining workflows, git hooks, and related tooling.

Usage:
```nix
github = v-utils.github {
  inherit pkgs pname;
  lastSupportedVersion = "nightly-1.86";
  jobsErrors = [ "rust-tests" ];
  jobsWarnings = [ "rust-clippy" "rust-machete" ];
  jobsOther = [ "loc-badge" ];
  langs = [ "rs" ];  # For gitignore generation
  labels = {
    defaults = true;  # Include default labels (default: true)
    extra = [         # Additional labels
      { name = "priority:high"; color = "ff0000"; }
    ];
  };
  preCommit = {
    semverChecks = true;  # Run cargo-semver-checks (default: false)
  };
};
```

Then use in devShell:
```nix
devShells.default = pkgs.mkShell {
  shellHook = github.shellHook;
  packages = [ ... ] ++ github.enabledPackages;
};
```

The shellHook will:
- Copy workflow files to .github/workflows/
- Set up git hooks (pre-commit with treefmt integration)
- Copy gitignore based on specified langs

enabledPackages includes:
- `git_ops` - GitHub operations (sync-labels, etc.)
'';
} else

let
  files = import ../files;

  workflows = import ./workflows/nix-parts {
    inherit pkgs lastSupportedVersion jobsErrors jobsWarnings jobsOther hookPre gistId;
  };

  # Process labels config
  defaultLabels = import ./labels.nix;
  labelsConfig = if builtins.isAttrs labels then labels else { extra = labels; };
  useDefaults = labelsConfig.defaults or true;
  extraLabels = labelsConfig.extra or [];
  allLabels = (if useDefaults then defaultLabels else []) ++ extraLabels;

  # Generate label args for git commands
  labelArgs = builtins.concatStringsSep " " (
    map (l: "-l '${l.name}:${l.color}'") allLabels
  );

  git_ops = import ./git.nix { inherit pkgs labelArgs; gitOpsScript = ./git_ops.rs; };

  # Process preCommit config
  semverChecks = preCommit.semverChecks or false;
in
{
  inherit workflows;
  inherit (workflows) errors warnings other;

  appendCustom = ./append_custom.rs;
  preCommit = import ./pre_commit.nix;

  inherit git_ops;

  shellHook = ''
    ${workflows.shellHook}
    cargo -Zscript -q ${./append_custom.rs} ./.git/hooks/pre-commit
    cp -f ${(files.gitignore { inherit pkgs; inherit langs;})} ./.gitignore
    cp -f ${(import ./pre_commit.nix) { inherit pkgs pname semverChecks traceyCheck; }} ./.git/hooks/custom.sh
  '';

  enabledPackages = [ git_ops ];
}
