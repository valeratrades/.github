# Changelog

## v1.4.0

**Breaking: `github` module**
- `jobsErrors`, `jobsWarnings`, `jobsOther` params removed. Use `jobs` instead:
  ```nix
  # old
  github = v-utils.github { jobsErrors = [ "rust-tests" ]; jobsWarnings = [ "rust-clippy" ]; };
  # new
  github = v-utils.github { jobs = { default = true; }; };
  # or granular:
  github = v-utils.github { jobs.errors.augment = [ "rust-miri" ]; jobs.warnings.exclude = [ "rust-doc" ]; };
  ```
- `jobs = { default = true; }` auto-populates jobs based on `langs` (e.g. `rs` gives rust-tests, rust-clippy, etc.)
- New params: `preCommit = { semverChecks = false; }`, `traceyCheck`, `styleCheck`

**Breaking: `rs` module**
- `build` param restructured: `log_directives`/`git_version` bools replaced by `build.workspace` map:
  ```nix
  # old
  build = { log_directives = true; git_version = true; };
  # new
  build.workspace = { "./" = [ "git_version" "log_directives" ]; };
  ```
- New params: `deny`, `tracey`, `style` (bool at v1.4.0, later becomes attrset)
- Now exposes `enabledPackages` - add to `packages` in devShell

### v1.4.1-10
- `defaults` param on `readme-fw` - when `true`, `licenses` can be omitted (defaults to Blue Oak)
- `rs.build`: `deprecate` module parses `since` markings, `force` mode added
- `rust-unused-features` added to default rs jobs

### v1.4.11-20
- `codestyle` replaces `rust_style`: `rs.style` changes from `bool` to attrset:
  ```nix
  # old
  style = true;
  # new
  style = { format = true; check = false; modules = { instrument = true; }; };
  ```
- `rust_style.rs` expanded: recognizes missing embeds for format strings
- `build.rs` modules now generate named functions; fixed extra closing brace bug
- `readme_fw`: architecture link joined into best_practices footnote
- Pre-commit: `nuke-snapshots` added for rs
- Codestyle version auto-bumping in CI

### v1.4.21-30
- Label sync now runs silently in background; on failure retries with output on next shell entry
- `binstall` integration: `releaseLatest` on `github` module for rolling releases per platform
- `default: bool` convention replaces `= {}` for defaults across modules
- Bump script fixes for personal binstalls
- `defaults` primitive added to `utils` to prevent naming mismatches (`default`/`defaults` aliases)

### v1.4.31-40
- **Breaking: `rs` now requires `rust` param** (the nix toolchain package):
  ```nix
  rs = v-utils.rs { inherit pkgs rust; };
  ```
  This prepends nix rust to PATH so it takes precedence over rustup shims.
- Release workflow fixes
- Bump script hardcodes removed

### v1.4.41-50
- GitLab mirror sync: `gitlabSync = { mirrorBaseUrl = "https://gitlab.com/user"; }` on `github`
  - Requires `GITLAB_TOKEN` secret
- `github` module accepts `rs` param to inherit style/tracey settings automatically:
  ```nix
  github = v-utils.github { inherit pkgs pname rs; };
  ```
- Binstall hook forces updates when outdated
- Gitignore matching improvements

### v1.4.51-60
- `v-utils.utils.combine` helper to merge modules:
  ```nix
  combined = v-utils.utils.combine [ rs github readme ];
  # then: packages = combined.enabledPackages; shellHook = combined.shellHook;
  ```
- `code-duplication` GHA workflow added (shared warning job)
- Lazy codestyle install (at pre-commit time, not shell entry)
- Treefmt no longer gets stuck with prompts

### v1.4.61-70
- `jobs.errors.install = { packages = [ "wayland" ]; }` - nix packages for CI jobs
- Qlty init fixes
- `enabledPackages` on `github` now includes `treefmt`

### v1.4.71-80
- LD_LIBRARY_PATH set for runtime library loading in CI
- `openssl.out` and `openssl.dev` auto-included in nix deps for jobs
- Dep updates now only run on minor+ version bumps (not patches)

### v1.4.81-87
- GitLab sync: LFS handling (skip during push, upload separately, disable LFS on mirror)
- `rs.targets` param for extra cargo target config in `.cargo/config.toml`
- Label sync state caching
- Readme-fw: logo auto-discovery from `.readme_assets/logo.(md|html)`

---

## v1.3.0

**New: `rs` module** for Rust project configuration:
```nix
rs = v-utils.rs {
  inherit pkgs;
  cranelift = true;
  build = { log_directives = true; git_version = true; };
};
# use rs.shellHook and add to devShell
```
- Copies rustfmt.toml, cargo config, generates build.rs
- `files.rust.build` added

### v1.3.1-3
- `rs.build`: doesn't assume top-level placement; uses parent dir of manifest file
- `cargo-semver-checks` added to pre-commit for rs
- Build.rs formatting fix

### v1.3.4-6
- `deprecate` module for build.rs: enforce removal of `#[deprecated]` items by version
- Lazy loading for build.rs modules
- `force` option on deprecation to rewrite all `since` attributes

### v1.3.7-10
- `cargo-deny` integration (`deny.toml` copied to project)
- `tracey` spec coverage tool integration
- `rust_style.rs` linter added
- Pre-commit: semver-checks

---

## v1.2.0

**New: `git_ops` with `sync-labels`** - automatic GitHub label synchronization:
```nix
github = v-utils.github {
  # ...existing params...
  labels = { defaults = true; extra = [{ name = "custom"; color = "ff0000"; }]; };
};
```
- `enabledPackages` now includes `git_ops` (was `git`)

### v1.2.1-4
- `build.rs` added to `files.rust`
- Optional `cranelift` backend support in cargo config
- Label duplicate color detection

---

## v1.1.0

**Breaking: `hooks` module merged into `github`**

```nix
# old (v1.0)
shellHook = ''
  ${v-utils.hooks.treefmt}
  ${v-utils.hooks.preCommit}
'';

# new (v1.1)
github = v-utils.github { inherit pkgs pname; langs = [ "rs" ]; };
# github.shellHook handles workflows + hooks + gitignore
# github.enabledPackages has required packages
```
- `v-utils.hooks` still exists as deprecated backward-compat alias
- `treefmt.nix` moved from `hooks/` to `files/`
- New: `v-utils.utils` module with `setDefaultEnv` and `requireEnv` helpers

---

## v1.0.0

Initial release. Modules:
- `files`: licenses (plain paths), rustfmt, deny, toolchain, config, clippy, python/ruff, golang/gofumpt, gitignore, gitattributes
- `hooks`: treefmt, pre-commit, append_custom
- `readme-fw`: README generation from `.readme_assets/`
- `workflows`/`ci`: GHA workflow generation

---

## Migration cheat-sheet

**v1.2 projects -> latest** (ask_llm, nautilus, polymarket_mm, prettify_log, shorts_basket, site, snapshot_fonts):
1. Change ref to `v1.4`
2. `files.licenses.blue_oak` is now `{ name = "..."; path = ...; }`, not a plain path.
   If using `readme-fw` with `defaults = true`, you can drop explicit license params entirely.
3. `readme-fw` licenses changed from `[{ name = "Blue Oak 1.0.0"; outPath = "LICENSE"; }]` to `[{ license = v-utils.files.licenses.blue_oak; }]`
4. `github` params: replace `jobsErrors`/`jobsWarnings`/`jobsOther` with `jobs = { default = true; }`
5. Add `rs = v-utils.rs { inherit pkgs rust; };` if using Rust
6. Pass `rs` to `github`: `github = v-utils.github { inherit pkgs pname rs; };`
7. Consider using `v-utils.utils.combine [ rs github readme ]` instead of manually joining shellHooks

**v1.3 projects -> latest** (tg_admin):
1. Change ref to `v1.4`
2. Steps 3-7 above
3. `rs` module: `build` param changed from `{ log_directives; git_version; }` to `{ workspace = { "./" = [...]; }; }`
4. `rs` now requires `rust` param: `v-utils.rs { inherit pkgs rust; }`
5. `style` changed from bool to attrset: `style = { format = true; check = false; }`
