{
	description = "Random tools for interfacing with github hooks";
	outputs = { self }: {
		appendCustom = ./append_custom.rs;
		#treefmt = ./treefmt.tom;l
		treefmt = (import ./treefmt.nix);
	};
}
