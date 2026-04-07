# Error Handling

Stack: `thiserror` + `miette` + `std::backtrace::Backtrace`.

## Pattern

```rust
use std::backtrace::Backtrace;

#[derive(Debug, thiserror::Error, miette::Diagnostic)]
pub enum MyError {
    // Leaf variant: capture backtrace at construction
    #[error("thing {name} is invalid")]
    #[diagnostic(code(mycrate::invalid))]
    Invalid {
        name: String,
        backtrace: Backtrace,
    },

    // Wrapping a foreign error (no backtrace in source): capture own
    #[error("io failed")]
    #[diagnostic(code(mycrate::io))]
    Io {
        #[from]
        source: std::io::Error,
        backtrace: Backtrace,  // auto-captured by #[from] generated From impl
    },

    // Wrapping our own error (already has backtrace): delegate, no field needed
    #[error(transparent)]
    #[diagnostic(transparent)]
    Inner(#[from] #[backtrace] InnerError),
}
```

## Crate setup

Any crate whose error types have a `backtrace: Backtrace` field needs this feature gate in `lib.rs` (thiserror's `provide()` impl uses the unstable `Request` API):

```rust
#![feature(error_generic_member_access)]
```

## Rules

**Leaf errors** (constructed fresh, no source): add `backtrace: Backtrace` field. Use `derive_new::new` with `#[new(value = "Backtrace::capture()")]` so construction sites never write `Backtrace::capture()` manually:

```rust
#[derive(Debug, thiserror::Error, miette::Diagnostic, derive_new::new)]
#[error("thing {name} is invalid")]
pub struct InvalidError {
    name: String,
    #[new(value = "Backtrace::capture()")]
    backtrace: Backtrace,
}

// Construction site — no Backtrace::capture() visible:
return Err(InvalidError::new(name));
```

For enum variants, derive_new generates `new_snake_case_variant_name()` constructors:

```rust
#[derive(Debug, thiserror::Error, miette::Diagnostic, derive_new::new)]
pub enum MyError {
    #[error("thing missing")]
    Missing { #[new(value = "Backtrace::capture()")] backtrace: Backtrace },
    #[error("bad value: {val}")]
    BadValue { val: String, #[new(value = "Backtrace::capture()")] backtrace: Backtrace },
}

MyError::new_missing()
MyError::new_bad_value("x".into())

**Wrapping foreign errors** (std, reqwest, serde_json, etc.): add both `#[from]` on source field and `backtrace: Backtrace` field. The generated `From` impl auto-calls `Backtrace::capture()` — no manual capture needed at `?` sites.

```rust
some_io_result?;  // From impl captures backtrace automatically
```

**Wrapping our own errors** (which already carry a backtrace): use `#[from] #[backtrace]` on the source field, no `backtrace` field on this variant. `#[backtrace]` makes `provide()` delegate to the source rather than capturing a new one.

```rust
#[error(transparent)]
#[diagnostic(transparent)]
Inner(#[from] #[backtrace] InnerError),
```

## `Other(Report)` escape hatch

Many error enums have an `Other(eyre::Report)` catch-all. Do not give it a diagnostic code — it's useless (nobody matches on `err.code()` strings in practice). Just use `#[error(transparent)]`:

```rust
#[error(transparent)]
Other(eyre::Report),
```

Diagnostic codes only make sense on typed variants where the code communicates something actionable.

## Environment
`Backtrace::capture()` returns a disabled backtrace unless `RUST_BACKTRACE=1` (or `RUST_LIB_BACKTRACE=1`) is set at runtime.


## Other
- Always use a named `backtrace: Backtrace` field (not a tuple position like `MyError(Backtrace)`) — `#[new(value = "...")]` from `derive_new` only works on named fields.
