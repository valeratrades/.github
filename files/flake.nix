{
	description = "Project conf files";
	outputs = { self }: {
		licenses = {
			blue_oak = builtins.readFile ./licenses/BlueOak_1-0-0.md;
		};
	};
}

