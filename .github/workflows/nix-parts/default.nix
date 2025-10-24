{ pkgs, lastSupportedVersion ? null, jobsErrors, jobsWarnings }:
let
  files = {
		# shared {{{
    base = ./shared/base.nix;
    tokei = ./shared/tokei.nix;
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
             else jobArgs;

      # Import the file
      imported = import (builtins.getAttr jobName files);

      # Check if it's a function (needs to be called) or already a value (attrset)
      value = if builtins.isFunction imported
              then imported args
              else imported;
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
in
{
	#TODO!!!!!!!: construct all of this procedurally, as opposed to hardcoding `jobs` and `env` base to `rust-base`
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
}
