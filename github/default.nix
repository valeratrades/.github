args@{ pkgs ? null, nixpkgs ? null, pname ? null, lastSupportedVersion ? null, jobs ? {}, hookPre ? {}, gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb", langs ? ["rs"], labels ? {}, preCommit ? {}, traceyCheck ? false, styleCheck ? true }:

# If called with just nixpkgs (for flake description), return description attribute
if nixpkgs != null && pkgs == null then {
  description = ''
GitHub integration module combining workflows, git hooks, and related tooling.

Usage:
```nix
github = v-utils.github {
  inherit pkgs pname;
  lastSupportedVersion = "nightly-1.86";
  langs = [ "rs" ];  # For gitignore generation

  # Jobs configuration - new interface
  jobs = {
    default = true;  # Enable defaults for all sections (based on langs)

    # Or configure each section individually:
    errors = {
      default = true;        # Enable default error jobs for langs
      augment = [ "rust-miri" ];  # Add extra jobs
      exclude = [ "rust-doc" ];   # Remove from defaults
    };
    warnings = {
      default = true;
      augment = [ { name = "rust-clippy"; args.extra = "--all-features"; } ];
    };
    other = {
      default = true;
      augment = [ "loc-badge" ];
    };
  };

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

  # Default jobs per language
  defaultJobsByLang = {
    rs = {
      errors = [ "rust-tests" ];
      warnings = [ "rust-doc" "rust-clippy" "rust-machete" "rust-sorted" "rust-sorted-derives" "tokei" ];
      other = [];
    };
    go = {
      errors = [ "go-tests" ];
      warnings = [ "go-gocritic" "go-security-audit" ];
      other = [];
    };
  };

  # Default other jobs for all languages
  defaultOther = [ "loc-badge" ];

  # Compute defaults based on langs
  computeDefaultsForLangs = category:
    let
      langJobs = builtins.concatLists (map (lang:
        (defaultJobsByLang.${lang}.${category} or [])
      ) langs);
    in
    if category == "other" then defaultOther ++ langJobs else langJobs;

  # Process a jobs section (errors, warnings, or other)
  # Takes: { default? = bool; augment? = [...]; exclude? = [...]; } or just a list (legacy)
  processJobsSection = category: sectionConfig: topDefault:
    let
      # Handle legacy list format
      isLegacyList = builtins.isList sectionConfig;
      section = if isLegacyList then { augment = sectionConfig; } else sectionConfig;

      # Determine if defaults should be enabled for this section
      sectionDefault = section.default or topDefault;

      # Get base jobs from defaults if enabled
      baseJobs = if sectionDefault then computeDefaultsForLangs category else [];

      # Get augment and exclude lists
      augmentJobs = section.augment or [];
      excludeJobs = section.exclude or [];

      # Helper to get job name from spec (handles both string and attrset)
      getJobName = spec: if builtins.isString spec then spec else spec.name;

      # Filter out excluded jobs
      filteredBase = builtins.filter (job:
        !(builtins.elem (getJobName job) excludeJobs)
      ) baseJobs;
    in
    filteredBase ++ augmentJobs;

  # Get top-level default setting
  topDefault = jobs.default or false;

  # Process each section
  jobsErrors = processJobsSection "errors" (jobs.errors or {}) topDefault;
  jobsWarnings = processJobsSection "warnings" (jobs.warnings or {}) topDefault;
  jobsOther = processJobsSection "other" (jobs.other or {}) topDefault;

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
    cp -f ${(import ./pre_commit.nix) { inherit pkgs pname semverChecks traceyCheck styleCheck; }} ./.git/hooks/custom.sh
  '';

  enabledPackages = [ git_ops ];
}
