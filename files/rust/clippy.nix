{ pkgs}:
(pkgs.formats.toml { }).generate "clippy.toml" {
	"allow-print-in-tests" = true;
	"allow-expect-in-tests" = true;
	"allow-unwrap-in-tests" = true;
	"allow-dbg-in-tests" = true;
	# disallowed-methods = [
	#     { path = "std::option::Option::map_or", reason = "prefer `map(..).unwrap_or(..)` for legibility" },
	#     { path = "std::option::Option::map_or_else", reason = "prefer `map(..).unwrap_or_else(..)` for legibility" },
	#     { path = "std::result::Result::map_or", reason = "prefer `map(..).unwrap_or(..)` for legibility" },
	#     { path = "std::result::Result::map_or_else", reason = "prefer `map(..).unwrap_or_else(..)` for legibility" },
	#     { path = "std::iter::Iterator::for_each", reason = "prefer `for` for side-effects" },
	#     { path = "std::iter::Iterator::try_for_each", reason = "prefer `for` for side-effects" },
	# ]
}
