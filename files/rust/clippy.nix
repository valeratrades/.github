{ pkgs}:
(pkgs.formats.toml { }).generate "clippy.toml" {
	"allow-print-in-tests" = true;
	"allow-expect-in-tests" = true;
	"allow-unwrap-in-tests" = true;
	"allow-dbg-in-tests" = true;
	"float_cmp" = "allow"; # is bad for `==` direct comparisons, but `<` and `>` should be allowed
	#get_first = "allow" # const fn, so actually is more performant, despite being annoying.
	"len_zero" = "allow"; # `.empty()` is O(1) but on &str only
	"undocumented_unsafe_blocks" = "warn";

	# disallowed-methods = [
	#     { path = "std::option::Option::map_or", reason = "prefer `map(..).unwrap_or(..)` for legibility" },
	#     { path = "std::option::Option::map_or_else", reason = "prefer `map(..).unwrap_or_else(..)` for legibility" },
	#     { path = "std::result::Result::map_or", reason = "prefer `map(..).unwrap_or(..)` for legibility" },
	#     { path = "std::result::Result::map_or_else", reason = "prefer `map(..).unwrap_or_else(..)` for legibility" },
	#     { path = "std::iter::Iterator::for_each", reason = "prefer `for` for side-effects" },
	#     { path = "std::iter::Iterator::try_for_each", reason = "prefer `for` for side-effects" },
	# ]
}
