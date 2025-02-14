{ pkgs, lastSupportedVersion, jobsErrors, jobsWarnings }:
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
    rust-sort = ./rust/sort.nix;
		#,}}}
    
		# go {{{
    go-tests = ./go/tests.nix;
    go-gocritic = ./go/gocritic.nix;
    go-security_audit = ./go/security_audit.nix;
		#,}}}
  };

	importFile = path:
    let file = builtins.getAttr path files;
    in if path == "rust-tests"
       then import file { inherit lastSupportedVersion; }
       else import file;

  constructJobs = paths: {
    jobs = map importFile paths;
  };
  
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
      permissions = (import files.base).permissions;
      env = (import files.rust-base).env;
      jobs = constructJobs jobsErrors;
    }
  );
  warnings = (pkgs.formats.yaml { }).generate "" (
    pkgs.lib.recursiveUpdate base {
      name = "Warnings";
      permissions = (import files.base).permissions;
      jobs = constructJobs jobsWarnings;
    }
  );
}
