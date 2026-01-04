# Architecture

v-utils is a Nix flake providing reusable components for project configuration. Each module is independent and composable.

## Module Overview

```
.
├── files/           # File templates (gitignore, treefmt, rustfmt, etc.)
├── github/          # GitHub integration (workflows, hooks, labels)
├── rs/              # Rust project configuration
├── readme_fw/       # README generation framework
├── utils/           # Shared utilities
└── best_practices/  # Documentation guidelines
```

## Module Dependencies

```
flake.nix (entry point)
    │
    ├── files/         (standalone - no dependencies)
    │
    ├── github/        (depends on: files/ for treefmt, gitignore)
    │
    ├── rs/            (depends on: files/ for rust configs)
    │
    ├── readme_fw/     (standalone)
    │
    └── utils/         (standalone - helper functions)
```

## Key Entry Points

- `flake.nix` - Main flake definition, exports all modules
- `*/default.nix` - Each module's entry point

## Data Flow

1. Consumer flake imports `v-utils`
2. Consumer calls module functions with config (e.g., `v-utils.rs { pkgs; tracey = true; }`)
3. Module returns:
   - `shellHook` - Commands to run on `nix develop`
   - `enabledPackages` - Packages to include in dev shell
   - Generated files/configs

## files/

Templates for project files. Each submodule generates a derivation containing the file.

- `gitignore/` - Language-specific gitignore rules
- `rust/` - rustfmt.toml, cargo config, deny.toml
- `treefmt.nix` - treefmt configuration
- `licenses/` - License file templates

## github/

GitHub-specific configuration:

- `workflows/` - CI workflow generation (errors.yml, warnings.yml)
- `pre_commit.nix` - Pre-commit hook with treefmt
- `labels.nix` - GitHub label synchronization
- `git_ops.rs` - Rust script for git operations

## rs/

Rust toolchain configuration:

- Generates `build.rs` for cranelift backend detection
- Integrates cargo-deny for dependency auditing
- Configures tracey for spec coverage
- Sets up codestyle linting

## readme_fw/

README generation from `.readme_assets/`:

- Reads `description.md`, `usage.md`, etc.
- Generates badges (msrv, crates.io, docs.rs, loc, ci)
- Compiles typst (`.typ`) to markdown if present
- Manages license file copying
