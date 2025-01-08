{
	description = "Random tools for interfacing with github hooks";
	outputs = { self }: {
		appendCustom = ./appendCustom.rs;
	};
}
