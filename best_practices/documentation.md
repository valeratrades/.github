## docs/
[developer docs](<https://matklad.github.io/2024/03/22/basic-things.html#Developer-Docs>) should _also_ contain a short landing page describing the structure of the documentation. This structure should allow for both a small number of high quality curated documents, and a large number of ad-hoc append-only notes on any particular topic. Normally:
- [ARCHITECTURE.md](#architecturemd)
- [CONTRIBUTING.md](#contributingmd)
, and explicitly say that everything else in the docs/ folder is a set of unorganized topical guides.

### marks on comments
- NB / NOTE: important
- HACK
- BUG
- PERF
- SAFETY
- XXX: like NB but strictly negative
- REF: link to reference or its summarized version in text
- LOOP: similar to SAFETY, _every_ endless loop must have an explanation for its necessity

#### temporary
When developing it's nice to be able to annotate approximate desired map of the next steps
As such, have 
- DO | \-: pseudo-code, mapping out steps needing to be done, similar to how `sorry` is used in `lean`, but obviously more urgent. Useful for grepping to find what I left at when coming back to a codebase.
- dbg | DBG: something temporary that is introduced for testing purposes and is meant to be removed before committing
- TEST: similar to DBG, marks places where I'm trying out a new thing. Should be removed after the result of the experiment is apparent.
- Q | ?: question to be resolved later
- TODO[!]*: todo, number of [!] signs for urgency
- MOVE: a special case of TODO, convenient for mapping out architecture changes. Simply says where a thing should be moved to eventually.


### ARCHITECTURE.md
[Must have]<https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html>)
Sections in architecture.md should write out their invariants [invariants](<https://matklad.github.io/2023/10/06/what-is-an-invariant.html>)

### CONTRIBUTING.md
Describes social architecture and [processes](<https://matklad.github.io/2024/03/22/basic-things.html#Process-Docs>)
Links to project-specific [STYLE.md](<https://matklad.github.io/2024/03/22/basic-things.html#Style>)

## README.md
- short one-page [README.md](<https://matklad.github.io/2024/03/22/basic-things.html#READMEs>) that is mostly links to more topical documentation. The two most important links are the user docs and the [dev docs](#docs)
