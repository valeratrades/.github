For developers, generally want to have a docs folder in the repository. The docs folder should _also_ contain a short landing page describing the structure of the documentation. This structure should allow for both a small number of high quality curated documents, and a large number of ad-hoc append-only notes on any particular topic. For example, docs/README.md could point to carefully crafted ARCHITECTURE.md and CONTRIBUTING.md, which describe high level code and social architectures, and explicitly say that everything else in the docs/ folder is a set of unorganized topical guides.

Common failure modes here:

1. There’s no place where to put new developer documentation at all. As a result, no docs are getting written, and, by the time you do need docs, the knowledge is lost.

1. There’s only highly structured, carefully reviewed developer documentation. Contributing docs requires a lot of efforts, and many small things go undocumented.

1. There’s only unstructured append-only pile of isolated documents. Things are _mostly_ documented, often two or there times, but any new team member has to do the wheat from the chaff thing anew.
