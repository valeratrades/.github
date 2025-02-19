{
  pkgs,
  ...
}: (pkgs.formats.toml { }).generate "ruff.toml" {
  # Basic settings
  line-length = 210;
  indent-width = 2;
  src = [ "src" "test" ];
  # not-in-test = false;

  # Formatting settings
  format = {
    quote-style = "double";
    indent-style = "tab";
    docstring-code-format = true; # false
    skip-magic-trailing-comma = false;
  };

  # Import sorting settings
  lint.isort = {
    combine-as-imports = true;
    required-imports = [ "from __future__ import annotations" ];
  };

  # Linting settings
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
      "E262"  # no-space-after-inline-comment
      "E713"
      "F403"
      "E401"
      "E714"  # `${value} is not` instead of `not ${value} is`
      "E722"
      "E703"  # don't complain about semicolons
      "E741"  # Ambiguous var name (I'm a Golang man)
      "F405"  # Warns when using anything from star imports
      # Line length regulated by formatter
      "E501"
      # pydocstyle: http://www.pydocstyle.org/en/stable/error_codes.html
      "D401"  # Relax NumPy docstring convention: First line should be in imperative mood
      # flake8-pytest-style:
      "PT011" # pytest.raises too broad
      # flake8-simplify
      "SIM102" # Use single `if` instead of nested
      "SIM108" # Use ternary operator
      # ruff
      "RUF005" # unpack-instead-of-concatenating-to-collection-literal
      # pycodestyle
      # TODO: Remove errors below to further improve docstring linting

      # Ordered from most common to least common errors.
      "D105"  # Missing docstring in magic method
      "D100"  # Missing docstring in public module
      "D104"  # Missing docstring in public package
      # flake8-todos
      "TD002" # Missing author in TODO
      "TD003" # Missing issue link after TODO
      # tryceratops
      "TRY003" # Avoid long messages outside exception class
      # Lints below are turned off because of conflicts with the ruff formatter
      "D206"
      "W191"
    ];
  };

  # Per-file ignore settings
  "lint.per-file-ignores"."tests/**/*.py" = [
    "D100"
    "D103"
    "B018"
    "FBT001"
  ];

  # PyDocStyle settings
  "lint.pydocstyle".convention = "numpy";
}
