{ pkgs }: (pkgs.formats.toml { }).generate "ruff.toml" {
  line-length = 210;
  indent-width = 2;
  src = [ "src" "test" ];
  # not-in-test = false;

  format = {
    quote-style = "double";
    indent-style = "tab";
    docstring-code-format = true; # false
    skip-magic-trailing-comma = false;
  };

  lint.isort = {
    combine-as-imports = true;
    required-imports = [ "from __future__ import annotations" ];
  };

  lint = {
    # Allow fix for all enabled rules (when `--fix`) is provided.
    fixable = [ "ALL" ];
    unfixable = [ ];
    dummy-variable-rgx = "^(_+|(_+[a-zA-Z0-9_]*[a-zA-Z0-9]+?))$";
    task-tags = [
      "TODO"
      "FIXME"
      "Q"
      "BUG"
      "NB"
    ];
    ignore = [
			"E261"  # Two spaces before inline comment
			"E262"  # Inline comment should start with '# '
			"E265"  # Block comment should start with '# '
			"E401"  # Multiline imports
      "D100"  # Missing docstring in public module
      "D104"  # Missing docstring in public package
      "D105"  # Missing docstring in magic method
      "D206" # conflicts with ruff formatter
      "D401"  # Relax NumPy docstring convention: First line should be in imperative mood
      "E262"  # no-space-after-inline-comment
      "E401"
      "E501" # Line length regulated by formatter
      "E703"  # don't complain about semicolons
      "E713"
      "E714"  # `${value} is not` instead of `not ${value} is`
      "E722"
      "E741"  # Ambiguous var name (I'm a Golang man)
      "F403"
      "F405"  # Warns when using anything from star imports
      "PT011" # pytest.raises too broad
      "RUF005" # unpack-instead-of-concatenating-to-collection-literal
      "SIM102" # Use single `if` instead of nested
      "SIM108" # Use ternary operator
      "TD002" # Missing author in TODO
      "TD003" # Missing issue link after TODO
      "TRY003" # Avoid long messages outside exception class
      "W191" # conflicts with ruff formatter
    ];
  };

  lint.per-file-ignores."tests/**/*.py" = [
    "D100"
    "D103"
    "B018"
    "FBT001"
  ];

  lint.pydocstyle.convention = "numpy";
}
