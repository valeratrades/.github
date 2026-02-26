args@{ pkgs ? null, nixpkgs ? null, pname ? null, lastSupportedVersion ? null, jobs ? {}, hookPre ? {}, gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb", langs ? ["rs"], labels ? {}, preCommit ? {},
  # Pass the rs module output to inherit style/tracey settings automatically
  rs ? null,
  # Or override individually (these take precedence over rs)
  traceyCheck ? null, style ? null, styleFormat ? null, styleAssert ? null, moduleFlags ? null,
  # Top-level install applies to all job sections (errors, warnings, other, release)
  # Per-section install overrides this.
  install ? {},
  release ? null, gitlabSync ? null,
}:

# Priority: explicit params > rs module > defaults
let
  # Extract from rs if provided
  rsTraceyCheck = if rs != null then (rs.traceyCheck or false) else false;
  rsStyleFormat = if rs != null then (rs.styleFormat or true) else true;
  rsStyleAssert = if rs != null then (rs.styleAssert or false) else false;
  rsModuleFlags = if rs != null then (rs.moduleFlags or "") else "";
  rsCodestyleLazyInstall = if rs != null then (rs.codestyleLazyInstall or "") else "";

  # Compute from style parameter if provided (for standalone usage without rs)
  styleModules = if style != null then (style.modules or {}) else {};
  valueToString = value:
    if builtins.isBool value then (if value then "true" else "false")
    else builtins.toString value;
  computedModuleFlags = builtins.concatStringsSep " " (
    builtins.attrValues (builtins.mapAttrs (name: value:
      "--${builtins.replaceStrings ["_"] ["-"] name}=${valueToString value}"
    ) styleModules)
  );
  styleParamFormat = if style != null then (style.format or null) else null;
  styleParamAssert = if style != null then (style.check or null) else null;

  # Final values: explicit > style param > rs > defaults
  actualTraceyCheck = if traceyCheck != null then traceyCheck else rsTraceyCheck;
  actualStyleFormat = if styleFormat != null then styleFormat
                      else if styleParamFormat != null then styleParamFormat
                      else rsStyleFormat;
  actualStyleAssert = if styleAssert != null then styleAssert
                      else if styleParamAssert != null then styleParamAssert
                      else rsStyleAssert;
  actualModuleFlags = if moduleFlags != null then moduleFlags
                      else if computedModuleFlags != "" then computedModuleFlags
                      else rsModuleFlags;
in

# If called with just nixpkgs (for flake description), return description attribute
if nixpkgs != null && pkgs == null then {
  description = ''
GitHub integration module combining workflows, git hooks, and related tooling.

Usage:
```nix
github = v-utils.github {
  inherit pkgs pname rs;  # Pass rs to inherit style/tracey settings
  lastSupportedVersion = "nightly-1.86";
  langs = [ "rs" ];  # For gitignore generation

  # Top-level install applies to all sections (errors, warnings, other, release)
  # Per-section install overrides this.
  install = { packages = [ "mold" "pkg-config" ]; };

  # Jobs configuration - new interface
  jobs = {
    default = true;  # Enable defaults for all sections (based on langs)

    # Or configure each section individually:
    errors = {
      default = true;        # Enable default error jobs for langs
      augment = [ "rust-miri" ];  # Add extra jobs
      exclude = [ "rust-doc" ];   # Remove from defaults
      install = { packages = [ "wayland" "libxkbcommon" ]; };  # Per-section override
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
  # Style settings are inherited from rs module automatically.
  # Override with style = { ... } or traceyCheck = ... if needed.

  # Binary releases — one workflow per target (release-{shortName}.yml)
  # Enabled by presence, disabled with `enable = false`
  release = { };  # Defaults: tag trigger, standard targets
  # OR customize:
  release = {
    targets = [ "x86_64-unknown-linux-gnu" "x86_64-apple-darwin" "aarch64-apple-darwin" ];
    aptDeps = [ "libssl-dev" ];  # Optional apt deps for linux builds
    # trigger: "tag" (default), "release_branch", or both:
    trigger = [ "tag" "release_branch" ];
    branch = "release";  # Branch for release_branch trigger (default: "release")
  };

  # GitLab mirror sync (triggers on any push)
  gitlabSync = { mirrorBaseUrl = "https://gitlab.com/user"; };
  # Repo name appended from GitHub context. Requires GITLAB_TOKEN secret
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
  sharedWarnings = [ "tokei" "code-duplication" ]; #TEST: if code-duplication works for other languages
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

  # Extract install config from each section, falling back to top-level install
  effectiveInstall = section:
    if builtins.isAttrs section && section ? install then section.install
    else install;
  installErrors = effectiveInstall (jobs.errors or {});
  installWarnings = effectiveInstall (jobs.warnings or {});
  installOther = effectiveInstall (jobs.other or {});

  workflows = import ./workflows/nix-parts {
    inherit pkgs lastSupportedVersion jobsErrors jobsWarnings jobsOther hookPre gistId release gitlabSync;
    inherit installErrors installWarnings installOther;
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

  # Label sync runs silently in background to avoid blocking shell startup.
  # On failure, it writes to a lock file. Next shell entry detects the lock
  # and runs sync sequentially with full output so errors are visible.
  # Uses double-fork via subshell + nohup to fully detach from parent shell.
  labelSyncHook = if labelsEnabled then ''
    _label_sync_lock="/tmp/$(echo -n "$PWD" | sha256sum | cut -d' ' -f1).lock"
    if [[ -f "$_label_sync_lock" ]]; then
      echo "Previous label sync failed, running with output..."
      if ${git_ops}/bin/git_ops sync-labels; then
        rm -f "$_label_sync_lock"
      fi
    else
      (nohup sh -c '${git_ops}/bin/git_ops sync-labels 2>&1 || echo "$?" > "'"$_label_sync_lock"'"' >/dev/null 2>&1 &)
    fi
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
    cp -f ${(import ./pre_commit.nix) { inherit pkgs pname semverChecks; traceyCheck = actualTraceyCheck; styleFormat = actualStyleFormat; styleAssert = actualStyleAssert; moduleFlags = actualModuleFlags; codestyleLazyInstall = rsCodestyleLazyInstall; }} ./.git/hooks/custom.sh
    ${labelSyncHook}
  '';

  enabledPackages = [ git_ops pkgs.treefmt ] ++ (if semverChecks then [ pkgs.cargo-semver-checks ] else []); #Q: not sure if this is the right place to bring in `treefmt`. But git-hooks seems to have had seized managing it correctly, so keep it here for now.
}
