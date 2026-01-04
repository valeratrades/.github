Collection of reusable Nix components for project configuration.

# Modules

## rs
Rust project configuration combining rustfmt, cargo config, and build.rs generation.
- Cranelift backend support
- cargo-deny integration
- [tracey](https://github.com/bearcove/tracey) spec coverage
- [codestyle](https://crates.io/crates/codestyle) linting

## github
GitHub integration: workflows, git hooks, gitignore, and label sync.
- Pre-commit hooks with treefmt
- CI workflow generation (errors, warnings, other)
- Automatic gitignore based on project languages

## files
File templates: rustfmt.toml, cargo config, deny.toml, treefmt, gitignore.

## readme-fw
README generation framework from `.readme_assets/` directory.
- Supports `.md` and `.typ` sources
- Badge generation (msrv, crates.io, docs.rs, loc, ci)
- License file management
