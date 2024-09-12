## docs/
[developer docs](<https://matklad.github.io/2024/03/22/basic-things.html#Developer-Docs>) should _also_ contain a short landing page describing the structure of the documentation. This structure should allow for both a small number of high quality curated documents, and a large number of ad-hoc append-only notes on any particular topic. Normally:
- [ARCHITECTURE.md](#architecturemd)
- [CONTRIBUTING.md](#contributingmd)
, and explicitly say that everything else in the docs/ folder is a set of unorganized topical guides.

### marks on comments
- NB: important
- Q | ?: question to be resolved later
- \-: pseudo-code
- TODO[!]*: todo, number of [!] signs for urgency
- HACK
- BUG
- PERF
- SAFETY
- FUCK: like NB but strictly negative. It hilariously adds to succinctness, so that's now part of the syntaxis.


### ARCHITECTURE.md
[Must have]<https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html>)
Sections in architecture.md should write out their invariants [invariants](<https://matklad.github.io/2023/10/06/what-is-an-invariant.html>)

### CONTRIBUTING.md
Describes social architecture and [processes](<https://matklad.github.io/2024/03/22/basic-things.html#Process-Docs>)
Links to project-specific [STYLE.md](<https://matklad.github.io/2024/03/22/basic-things.html#Style>)

## README.md
- short one-page [README.md](<https://matklad.github.io/2024/03/22/basic-things.html#READMEs>) that is mostly links to more topical documentation. The two most important links are the user docs and the [dev docs](#docs)
