[Push `for`s down and `if`s up](<https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html>)

## Error-handling
- Never fail on user input

## modules
try to avoid circular dependencies. For example, oftentimes when you have a large cluster of inter-connected types, it's better to keep them together in a single large file, rather then trying to arbitrarily reduce into thematic modules. Except, of course, for shared base-only elements, - each layer that is strictly derivative should have its own mod.
