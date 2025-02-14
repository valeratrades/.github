 {
	name = "leptosfmt";
	runs-on = "ubuntu-latest";
	steps = [
    { uses =  "actions/checkout@v4"; }
		{ uses = "LesnyRumcajs/leptosfmt-action@v0.1.0"; }
	];
}
