args@{ pkgs ? null, nixpkgs ? null, lastSupportedVersion ? null, jobsErrors, jobsWarnings, jobsOther ? [], hookPre ? {}, gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb", release ? null, releaseLatest ? null }:

# If called with just nixpkgs (for flake description), return description attribute
if nixpkgs != null && pkgs == null then {
  description = ''
GitHub Actions workflow generator for Nix projects.

Note: This module is typically used via github/default.nix which provides
a higher-level interface with default job selection based on langs.

Direct usage (low-level):
```nix
workflows = import ./github/workflows/nix-parts {
  inherit pkgs;
  lastSupportedVersion = "nightly-1.86";
  jobsErrors = [ "rust-tests" "rust-doc" ];
  # Or with args: { name = "rust-tests"; args.skipPatterns = [ "pattern1" "pattern2" ]; }
  jobsWarnings = [ "rust-clippy" "rust-machete" ];
  jobsOther = [ "loc-badge" ];
};
```

Available jobs: rust-tests, rust-doc, rust-miri, rust-clippy, rust-machete, rust-sorted, rust-sorted-derives, rust-unused-features, rust-leptosfmt, go-tests, go-gocritic, go-security-audit, tokei, loc-badge

Standalone workflows:
- release = { default = true; } or release = { targets = [...]; ... }
    Binary release for cargo-binstall (triggers on v* tags)
    Default targets: x86_64-unknown-linux-gnu, x86_64-apple-darwin, aarch64-apple-darwin
- releaseLatest = { default = true; } or releaseLatest = { platforms = [...]; ... }
    Rolling "latest" releases per platform (triggers on branch push)
    Available platforms: debian, windows, macos
'';
} else

# Otherwise, generate workflows
let
  files = {
		# shared {{{
    base = ./shared/base.nix;
    tokei = ./shared/tokei.nix;
    loc-badge = ./shared/loc-badge.nix;
		#,}}}

		# rust {{{
    rust-base = ./rust/base.nix;
		rust-tests = ./rust/tests.nix;
    rust-doc = ./rust/doc.nix;
    rust-miri = ./rust/miri.nix;
    rust-clippy = ./rust/clippy.nix;
    rust-machete = ./rust/machete.nix;
    rust-sorted = ./rust/sorted.nix;
    rust-sorted-derives = ./rust/sorted_derives.nix;
    rust-unused-features = ./rust/unused_features.nix;
    rust-release = ./rust/release.nix;
    rust-release-latest = ./rust/release-latest.nix;
		#,}}}

		# go {{{
    go-tests = ./go/tests.nix;
    go-gocritic = ./go/gocritic.nix;
    go-security-audit = ./go/security_audit.nix;
		#,}}}
  };

	importFile = jobSpec:
    let
      # Support both string and attrset (for passing args)
      jobName = if builtins.isString jobSpec then jobSpec else jobSpec.name;
      jobArgs = if builtins.isString jobSpec then {} else (jobSpec.args or {});

      # Build the arguments to pass to the imported file
      args = if jobName == "rust-tests"
             then { lastSupportedVersion = lastSupportedVersion; } // jobArgs
             else if jobName == "loc-badge"
             then { inherit gistId; } // jobArgs
             else jobArgs;

      # Import the file
      imported = import (builtins.getAttr jobName files);

      # Check if it's a function (needs to be called) or already a value (attrset)
      baseValue = if builtins.isFunction imported
                  then imported args
                  else imported;

      # Apply hookPre if specified for this job
      value = if builtins.hasAttr jobName hookPre
              then
                let
                  # Get the list of pre-hook commands for this job
                  preHookCmds = builtins.getAttr jobName hookPre;

                  # Convert each string command to a step attrset
                  preHookSteps = map (cmd: { run = cmd; }) preHookCmds;

                  # Prepend pre-hook steps to existing steps
                  modifiedSteps = preHookSteps ++ baseValue.steps;
                in
                baseValue // { steps = modifiedSteps; }
              else baseValue;
    in
    {
      name = jobName;
      inherit value;
    };

  constructJobs = paths: 
    builtins.listToAttrs (map importFile paths);
  
  base = {
    on = {
      push = { };
      pull_request = { };
      workflow_dispatch = { };
    };
  };
  # Check if release config is enabled (default = true required, custom fields override defaults)
  releaseEnabled = release != null && (
    (builtins.isAttrs release && (release.default or false))
    || release == true
  );
  releaseLatestEnabled = releaseLatest != null && (
    (builtins.isAttrs releaseLatest && (releaseLatest.default or false))
    || releaseLatest == true
  );

  # Standalone release workflow (binstall-compatible, triggers on v* tags)
  releaseWorkflow = if releaseEnabled then
    let
      releaseSpec = import files.rust-release (
        if builtins.isAttrs release then release else { default = true; }
      );
    in (pkgs.formats.yaml { }).generate "" (builtins.removeAttrs releaseSpec [ "standalone" "default" ])
  else null;

  # Rolling "latest" release workflows (per-platform, triggers on branch push)
  releaseLatestWorkflows = if releaseLatestEnabled then
    let
      spec = import files.rust-release-latest (
        if builtins.isAttrs releaseLatest then releaseLatest else { default = true; }
      );
    in builtins.mapAttrs (name: wf:
      (pkgs.formats.yaml { }).generate "" (builtins.removeAttrs wf [ "standalone" "filename" "default" ])
    ) spec.workflows
  else {};

  workflows = {
    #TODO!!!!: construct all of this procedurally, as opposed to hardcoding `jobs` and `env` base to `rust-base`
    #Q: Potentially standardize each file providing a set of outs, like `jobs`, `env`, etc, then manually join on them?
    errors = (pkgs.formats.yaml { }).generate "" (
      pkgs.lib.recursiveUpdate base {
        name = "Errors";
        permissions = (import files.base).permissions;
        env = (import files.rust-base).env;
        jobs = pkgs.lib.recursiveUpdate (import files.rust-base).jobs (constructJobs jobsErrors);
      }
    );

    warnings = (pkgs.formats.yaml { }).generate "" (
      pkgs.lib.recursiveUpdate base {
        name = "Warnings";
        permissions = (import files.base).permissions;
        env = (import files.rust-base).env;
        jobs = pkgs.lib.recursiveUpdate (import files.rust-base).jobs (constructJobs jobsWarnings);
      }
    );

    other = (pkgs.formats.yaml { }).generate "" (
      pkgs.lib.recursiveUpdate base {
        name = "Other";
        permissions = (import files.base).permissions;
        jobs = constructJobs jobsOther;
      }
    );
  };

  ensureBinstallScript = ../../ensure_binstall_metadata.rs;

  releaseHook = if releaseWorkflow != null then ''
    cp -f ${releaseWorkflow} ./.github/workflows/release.yml
    cargo -Zscript -q ${ensureBinstallScript}
  '' else "";

  releaseLatestHook = builtins.concatStringsSep "\n" (
    pkgs.lib.mapAttrsToList (name: wf: ''
      cp -f ${wf} ./.github/workflows/release-${name}.yml
    '') releaseLatestWorkflows
  );
in
workflows // {
  inherit releaseWorkflow releaseLatestWorkflows;
  shellHook = ''
    mkdir -p ./.github/workflows
    cp -f ${workflows.errors} ./.github/workflows/errors.yml
    cp -f ${workflows.warnings} ./.github/workflows/warnings.yml
    cp -f ${workflows.other} ./.github/workflows/other.yml
    ${releaseHook}
    ${releaseLatestHook}
  '';
}
