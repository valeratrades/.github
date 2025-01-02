{
	description = "GitHub workflow parts";
	outputs = { self }: {
		shared = {
			tokei = ./shared/tokei.nix;
			base = ./shared/base.nix;
		};
		rust = {
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
	};
}
