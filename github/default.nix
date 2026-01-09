args@{ pkgs ? null, nixpkgs ? null, pname ? null, lastSupportedVersion ? null, jobs ? {}, hookPre ? {}, gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb", langs ? ["rs"], labels ? {}, preCommit ? {}, traceyCheck ? false, style ? {}, release ? null, releaseLatest ? null,
  # Backwards compat: direct styleFormat/styleAssert/moduleFlags override style
  styleFormat ? null, styleAssert ? null, moduleFlags ? null,
}:

# Compute style settings from style parameter (mirroring rs/default.nix)
# Direct parameters (styleFormat, styleAssert, moduleFlags) take precedence for backwards compat
let
  styleModules = style.modules or {};
  valueToString = value:
    if builtins.isBool value then (if value then "true" else "false")
    else builtins.toString value;
  computedModuleFlags = builtins.concatStringsSep " " (
    builtins.attrValues (builtins.mapAttrs (name: value:
      "--${builtins.replaceStrings ["_"] ["-"] name}=${valueToString value}"
    ) styleModules)
  );
  actualStyleFormat = if styleFormat != null then styleFormat else (style.format or true);
  actualStyleAssert = if styleAssert != null then styleAssert else (style.check or false);
  actualModuleFlags = if moduleFlags != null then moduleFlags else computedModuleFlags;
in

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
    enable = true;    # Auto-sync labels on shell entry (default: true)
    defaults = true;  # Include default labels (default: true)
    extra = [         # Additional labels
      { name = "priority:high"; color = "ff0000"; description = "High priority"; }
    ];
  };
  preCommit = {
    semverChecks = false;  # Run cargo-semver-checks (default: false, can be very slow)
  };
  style = {               # Codestyle settings (same format as rs.style)
    format = true;        # Auto-fix style issues in pre-commit (default: true)
    check = false;        # Error on unfixable style issues (default: false)
    modules = {           # Toggle individual codestyle checks
      no_chrono = "false";
    };
  };

  # Binary releases for cargo-binstall (triggers on v* tags)
  release = { default = true; };  # Use defaults
  # OR customize:
  release = {
    targets = [ "x86_64-unknown-linux-gnu" "x86_64-apple-darwin" ];
    cargoFlags = { "x86_64-pc-windows-msvc" = "--no-default-features"; };
    aptDeps = [ "libssl-dev" "pkg-config" ];
  };

  # Rolling "latest" releases per platform (triggers on branch push)
  releaseLatest = { default = true; };  # Use defaults
  # OR customize:
  releaseLatest = {
    platforms = [ "debian" "windows" ];
    cargoFlags = { windows = "--no-default-features"; };
    aptDeps = [ "libssl-dev" ];
    branch = "release";
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
  utils = import ../utils;
  files = import ../files;

  # Shared defaults across all languages
  sharedWarnings = [ "tokei" ];
  sharedOther = [ "loc-badge" ];

  # Default jobs per language
  defaultJobsByLang = {
    rs = {
      errors = [ "rust-tests" ];
      warnings = [ "rust-doc" "rust-clippy" "rust-machete" "rust-sorted" "rust-sorted-derives" ]; #WAIT: until "rust-unused-features" finally gets --edition 2024 support
    };
    go = {
      errors = [ "go-tests" ];
      warnings = [ "go-gocritic" "go-security-audit" ];
    };
    py = {
      errors = [];
      warnings = [];
    };
  };

  # Compute defaults based on langs
  computeDefaultsForLangs = category:
    let
      langJobs = builtins.concatLists (map (lang:
        (defaultJobsByLang.${lang}.${category} or [])
      ) langs);
      shared = if category == "warnings" then sharedWarnings
               else if category == "other" then sharedOther
               else [];
    in
    langJobs ++ shared;

  # Process a jobs section (errors, warnings, or other)
  # Takes: { default? = bool; defaults? = bool; augment? = [...]; exclude? = [...]; } or just a list (legacy)
  # Accepts both `default` and `defaults` as aliases via optionalDefaults
  processJobsSection = category: sectionConfig: topDefault:
    let
      # Handle legacy list format
      isLegacyList = builtins.isList sectionConfig;
      sectionRaw = if isLegacyList then { augment = sectionConfig; } else sectionConfig;
      section = utils.optionalDefaults sectionRaw;

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

  # Get top-level default setting (accepts both `default` and `defaults`)
  jobsNormalized = utils.optionalDefaults jobs;
  topDefault = jobsNormalized.default;

  # Process each section
  jobsErrors = processJobsSection "errors" (jobs.errors or {}) topDefault;
  jobsWarnings = processJobsSection "warnings" (jobs.warnings or {}) topDefault;
  jobsOther = processJobsSection "other" (jobs.other or {}) topDefault;

  workflows = import ./workflows/nix-parts {
    inherit pkgs lastSupportedVersion jobsErrors jobsWarnings jobsOther hookPre gistId release releaseLatest;
  };

  # Process labels config (accepts both `default` and `defaults`)
  defaultLabels = import ./labels.nix;
  labelsConfigRaw = if builtins.isAttrs labels then labels else { extra = labels; };
  labelsConfig = utils.optionalDefaults labelsConfigRaw;
  labelsEnabled = labelsConfig.enable or true;
  useDefaults = labelsConfig.default or true;
  extraLabels = labelsConfig.extra or [];
  allLabels = (if useDefaults then defaultLabels else []) ++ extraLabels;

  # Generate label args for git commands
  # Need to escape for bash eval: escaped double quotes for nesting inside eval "..."
  escapeForEval = s: builtins.replaceStrings ["\"" "\\" "$" "`"] ["\\\"" "\\\\" "\\$" "\\`"] s;
  labelArgs = builtins.concatStringsSep " " (
    map (l: ''-l \"'' + escapeForEval l.name + ":" + l.color + ":" + escapeForEval (l.description or "") + ''\"'') allLabels
  );

  git_ops = import ./git.nix { inherit pkgs labelArgs; gitOpsScript = ./git_ops.rs; };

  # Process preCommit config
  # can be very slow
  semverChecks = preCommit.semverChecks or false;

  labelSyncHook = if labelsEnabled then ''
    ${git_ops}/bin/git_ops sync-labels &
  '' else "";
in
{
  inherit workflows;
  inherit (workflows) errors warnings other;

  appendCustom = ./append_custom.rs;
  preCommit = import ./pre_commit.nix;

  inherit git_ops labelSyncHook;

  shellHook = ''
    ${workflows.shellHook}
    cargo -Zscript -q ${./append_custom.rs} ./.git/hooks/pre-commit
    cp -f ${(files.gitignore { inherit pkgs; inherit langs;})} ./.gitignore
    cp -f ${(import ./pre_commit.nix) { inherit pkgs pname semverChecks traceyCheck; styleFormat = actualStyleFormat; styleAssert = actualStyleAssert; moduleFlags = actualModuleFlags; }} ./.git/hooks/custom.sh
    ${labelSyncHook}
  '';

  enabledPackages = [ git_ops ] ++ (if semverChecks then [ pkgs.cargo-semver-checks ] else []);
}
