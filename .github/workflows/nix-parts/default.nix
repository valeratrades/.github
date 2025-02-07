{ nixpkgs }: {
 description = "GitHub workflow parts";
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
}
