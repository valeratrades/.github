# General
Follow the conventional commits (aka the Angular convention).  
More specifically, as described in [conventional_commit_messages.md].  
Below are notable tips and caveats:

- Imperative, as if you are [giving orders to the codebase][SubmittingPatches]
- Present tense ("add", not "added")
- Do NOT capitalize the first letter
- Do NOT add period `.` at the end

[conventional_commit_messages.md]: <https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13>
[SubmittingPatches]: <https://git.kernel.org/pub/scm/git/git.git/tree/Documentation/SubmittingPatches?h=v2.36.1#n181>



## Prefixes
Adopted commit prefixes in my repositories are as follows:

- "feat:"
- "fix:"
- "chore:"
- "style:"
- "test:"
- "refactor:"
- "perf:"
- "docs:"

TODO: sync these from defined -p flags in [~/s/help_scripts/git.sh]

And a special commit message "_", interchangeable with "minor", indicating that the change is too small or insignificant to be mentioned

Every degree of specification is separated by ":" or ": ", so a commit with changed description of project structure could be titled as `docs: architecture: modules` or `docs: architecture`.

## Keywords
GitHub supports specific keywords that, when used in a commit message, automatically close the referenced issue once the commit is merged into the default branch. The most common keywords are:

- `close`
- `closes`
- `closed`
- `fix`
- `fixes`
- `fixed`
- `resolve`
- `resolves`
- `resolved`

**Example:**
```sh
git commit -m "Fix typo in README.md (fixes #42)"
```
