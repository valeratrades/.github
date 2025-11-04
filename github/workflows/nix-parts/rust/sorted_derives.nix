{
	name = "Sorted Derives";
	runs-on = "ubuntu-latest";
	steps = [
		{ uses = "actions/checkout@v4"; }
		{
			name = "Installation";
			uses = "taiki-e/install-action@v2";
			"with".tool = "cargo-sort-derives";
		}
		{
			name = "Assert derives are sorted";
			run = ''
				cargo sort-derives --check
				exit_code=$?
				if [ $exit_code != 0 ]; then
					echo "Derives are not sorted. Run \`cargo sort-derives\` to fix it."
					exit $exit_code
				fi
			'';
		}
	];
}

