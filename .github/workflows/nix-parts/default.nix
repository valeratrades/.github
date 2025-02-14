{ pkgs, lastSupportedVersion, jobsErrors, jobsWarnings }:
let
  shared = {
    base = ./shared/base.nix;
    tokei = ./shared/tokei.nix;
  };
  rust = {
    base = ./rust/base.nix;
    tests = ./rust/tests.nix;
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

  constructJobs = paths:
    let
      imports = map (path:
        if path == "rust.tests" then
					import ${path} { inherit lastSupportedVersion; }
        else
					import ${path}
      ) paths;
    in
    pkgs.lib.foldl pkgs.lib.recursiveUpdate { } imports;

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
