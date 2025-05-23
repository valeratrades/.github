{ pkgs }:
	(pkgs.formats.toml { }).generate "" {
	# Stable
	brace_style = "PreferSameLine";
	format_macro_matchers = true;
	group_imports = "StdExternalCrate";
	hard_tabs = true;
	hex_literal_case = "Lower";
	imports_granularity = "Crate";
	max_width = 190;
	normalize_doc_attributes = true;
	reorder_impl_items = true;
	reorder_imports = true;

	## Questionable
	#fn_single_line = true;
	match_arm_blocks = false;
	short_array_element_width_threshold = 20;

	# Unstable
	unstable_features = true;
	use_field_init_shorthand = true;
	use_small_heuristics = "Default"; # putting average line width of elements to about 55% of max_width
	use_try_shorthand = true;

	## Questionable
}
