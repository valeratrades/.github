# Error Handling

Stack: `thiserror` + `miette` + `std::backtrace::Backtrace` + `v_utils_macros::wrap_err`.

## Pattern

```rust
use v_utils_macros::wrap_err;

#[wrap_err]
#[derive(Debug, thiserror::Error, miette::Diagnostic)]
pub enum MyError {
    // Leaf variant: fresh error, no source — injects backtrace+spantrace, generates constructor
    #[leaf]
    #[error("thing {name} is invalid")]
    #[diagnostic(code(mycrate::invalid))]
    Invalid { name: String },

    // Wrapping a foreign error (no backtrace in source): captures own backtrace at ?
    #[foreign]
    Io(std::io::Error),

    // Wrapping our own error (already has backtrace): delegates, no new capture
    #[own]
    Inner(InnerError),
}
```

**Construction:**

```rust
// Leaf: generated constructor auto-captures backtrace+spantrace — no manual Backtrace::capture()
return Err(MyError::new_invalid(name));

// Foreign and Own: From impls fire at ? — nothing to write at call sites
some_io_result?;
produces_inner_result()?;
```

## Crate setup

Any crate whose error types have a `backtrace: Backtrace` field needs this feature gate in `lib.rs`:

```rust
#![feature(error_generic_member_access)]
```

## Rules

### Leaf errors

`#[leaf]` on a named or unit variant — no source, fresh error. The macro injects `backtrace: Backtrace` and `spantrace: SpanTrace` fields and generates a `new_snake_case_variant_name(…user_fields…)` constructor.

```rust
// What you write:
#[wrap_err]
#[derive(Debug, thiserror::Error, miette::Diagnostic)]
pub struct InvalidError {
    name: String,
}

// What it expands to (conceptually):
pub struct InvalidError {
    name: String,
    backtrace: std::backtrace::Backtrace,
    spantrace: tracing_error::SpanTrace,
}
impl InvalidError {
    pub fn new(name: String) -> Self {
        Self { name, backtrace: Backtrace::capture(), spantrace: SpanTrace::capture() }
    }
}

// Construction site — clean, no Backtrace::capture() visible:
return Err(InvalidError::new(name));
```

For enums, `new_snake_case_variant_name(…)` constructors are generated per `#[leaf]` variant.

### Wrapping foreign errors

`#[foreign]` on a tuple variant wrapping `std`, `reqwest`, `serde_json`, etc. The macro converts to named fields `{ source: T, backtrace, spantrace }` and generates a `From<T>` impl that captures backtrace+spantrace at the `?` site.

```rust
// What you write:
#[foreign]
Io(std::io::Error),

// What it expands to (conceptually):
#[error("{source}")]
Io { source: std::io::Error, backtrace: Backtrace, spantrace: SpanTrace },

impl From<std::io::Error> for MyError {
    fn from(source: std::io::Error) -> Self {
        Self::Io { source, backtrace: Backtrace::capture(), spantrace: SpanTrace::capture() }
    }
}

// At call site — From impl captures backtrace automatically:
some_io_result?;
```

### Wrapping our own errors

`#[own]` on a tuple variant wrapping one of our typed errors that already carries backtrace/spantrace. The macro adds `#[error(transparent)]` and `#[from]` + `#[backtrace]` to the inner field, so `thiserror`'s `provide()` delegates to the source's backtrace rather than capturing a new one.

```rust
// What you write:
#[own]
Inner(InnerError),

// What it expands to (conceptually):
#[error(transparent)]
Inner(#[from] #[backtrace] InnerError),

// thiserror then generates:
impl From<InnerError> for MyError {
    fn from(source: InnerError) -> Self { Self::Inner(source) }
}
// And provide() on MyError::Inner delegates to InnerError's provide(),
// so the original backtrace is preserved — not a new one captured here.

// At call site — nothing extra needed:
produces_inner_result()?;
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
- Always use a named `backtrace: Backtrace` field (not a tuple position like `MyError(Backtrace)`) — `#[new(value = "...")]` from `derive_new` only works on named fields. The `wrap_err` macro always injects named fields so this is handled automatically.
