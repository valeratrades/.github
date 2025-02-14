{ pkgs, lastSupportedVersion, jobsErrors, jobsWarnings }:
let
  shared = {
    base = ./shared/base.nix;
    tokei = ./shared/tokei.nix;
  };
  rust = {
    base = ./rust/base.nix;
    tests = import ./rust/tests.nix { inherit lastSupportedVersion; };
    doc = ./rust/doc.nix;
    miri = ./rust/miri.nix;
    clippy = ./rust/clippy.nix;
    machete = ./rust/machete.nix;
    sort = ./rust/sort.nix;
  };
  go = {
    tests = ./go/tests.nix;
    gocritic = ./go/gocritic.nix;
    security_audit = ./go/security_audit.nix;
  };

  # Lookup table to map strings to imported files
  lookupTable = {
    "shared.base" = shared.base;
    "shared.tokei" = shared.tokei;
    "rust.base" = rust.base;
    "rust.tests" = rust.tests;
    "rust.doc" = rust.doc;
    "rust.miri" = rust.miri;
    "rust.clippy" = rust.clippy;
    "rust.machete" = rust.machete;
    "rust.sort" = rust.sort;
    "go.tests" = go.tests;
    "go.gocritic" = go.gocritic;
    "go.security_audit" = go.security_audit;
  };

  # Function to construct jobs based on the lookup table
  constructJobs = jobNames: pkgs.lib.foldl (acc: jobName: 
    pkgs.lib.recursiveUpdate acc (import lookupTable.${jobName})
  ) {} jobNames;

  base = {
    on = {
      push = { };
      pull_request = { };
      workflow_dispatch = { };
    };
  };

in
{
  errors = (pkgs.formats.yaml { }).generate "" (
    pkgs.lib.recursiveUpdate base {
      name = "Errors";
      permissions = (import shared.base).permissions;
      env = (import rust.base).env;
      jobs = constructJobs jobsErrors;
    }
  );

  warnings = (pkgs.formats.yaml { }).generate "" (
    pkgs.lib.recursiveUpdate base {
      name = "Warnings";
      permissions = (import shared.base).permissions;
      jobs = constructJobs jobsWarnings;
    }
  );
}
