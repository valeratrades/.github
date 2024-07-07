### [Comparators](<https://matklad.github.io/2023/09/13/comparative-analysis.html>)
- prefer `<` and `<=` over `>` and `>=`
- state invariants positively:
    ```rs
    if (index >= xs.len) {
    }
    ```
    Is a double-negation semantically


