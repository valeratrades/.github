#!/usr/bin/env nix
---cargo
#! nix shell --impure --expr ``
#! nix let rust_flake = builtins.getFlake ''github:oxalica/rust-overlay'';
#! nix     nixpkgs_flake = builtins.getFlake ''nixpkgs'';
#! nix     pkgs = import nixpkgs_flake {
#! nix       system = builtins.currentSystem;
#! nix       overlays = [rust_flake.overlays.default];
#! nix     };
#! nix     toolchain = pkgs.rust-bin.nightly."2025-10-10".default.override {
#! nix       extensions = ["rust-src"];
#! nix     };
#! nix
#! nix in toolchain
#! nix ``
#! nix --command sh -c ``cargo -Zscript -q "$0" "$@"``

[package]
edition = "2024"

[dependencies]
syn = { version = "2", features = ["full", "parsing"] }
proc-macro2 = { version = "1", features = ["span-locations"] }
walkdir = "2"
---

//! Custom Rust style checks beyond what rustfmt and clippy provide.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use syn::spanned::Spanned;
use syn::{Item, ItemEnum, ItemStruct, ItemUnion};
use walkdir::WalkDir;

struct Violation {
    rule: &'static str,
    file: String,
    line: usize,
    message: String,
}

struct TypeDef {
    end_line: usize,
}

/// Find all src directories in a Cargo workspace
fn find_src_dirs(root: &Path) -> Vec<PathBuf> {
    let cargo_toml = root.join("Cargo.toml");
    if !cargo_toml.exists() {
        if root.exists() {
            return vec![root.to_path_buf()];
        }
        return vec![];
    }

    let content = match std::fs::read_to_string(&cargo_toml) {
        Ok(c) => c,
        Err(_) => return vec![root.join("src")],
    };

    // Simple parsing: look for members = [...] in [workspace]
    let mut in_workspace = false;
    let mut members = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed == "[workspace]" {
            in_workspace = true;
        } else if trimmed.starts_with('[') && trimmed != "[workspace]" {
            in_workspace = false;
        } else if in_workspace && trimmed.starts_with("members") {
            if let Some(start) = line.find('[') {
                if let Some(end) = line.find(']') {
                    let list = &line[start + 1..end];
                    for member in list.split(',') {
                        let member = member.trim().trim_matches('"').trim_matches('\'');
                        if !member.is_empty() && !member.contains('*') {
                            members.push(member.to_string());
                        }
                    }
                }
            }
        }
    }

    if members.is_empty() {
        let src = root.join("src");
        if src.exists() {
            return vec![src];
        }
        return vec![];
    }

    members
        .into_iter()
        .filter_map(|m| {
            let src = root.join(&m).join("src");
            if src.exists() { Some(src) } else { None }
        })
        .collect()
}

/// Check: impl blocks must immediately follow their type definition
fn check_impl_follows_type(path: &Path, file: &syn::File) -> Vec<Violation> {
    const RULE: &str = "impl-follows-type";

    let path_str = path.display().to_string();
    let mut type_defs: HashMap<String, TypeDef> = HashMap::new();
    let mut violations = Vec::new();

    // First pass: collect all type definitions
    for item in &file.items {
        let (name, end_line) = match item {
            Item::Struct(ItemStruct { ident, .. }) => {
                (ident.to_string(), item.span().end().line)
            }
            Item::Enum(ItemEnum { ident, .. }) => {
                (ident.to_string(), item.span().end().line)
            }
            Item::Union(ItemUnion { ident, .. }) => {
                (ident.to_string(), item.span().end().line)
            }
            _ => continue,
        };

        type_defs.insert(name, TypeDef { end_line });
    }

    // Second pass: check impl blocks
    for item in &file.items {
        let Item::Impl(impl_block) = item else {
            continue;
        };

        let type_name = match &*impl_block.self_ty {
            syn::Type::Path(type_path) => {
                type_path.path.segments.last().map(|s| s.ident.to_string())
            }
            _ => None,
        };

        let Some(type_name) = type_name else {
            continue;
        };

        // Skip trait impls - only check inherent impls
        if impl_block.trait_.is_some() {
            continue;
        }

        let Some(type_def) = type_defs.get(&type_name) else {
            continue;
        };

        let impl_start_line = impl_block.span().start().line;
        let expected_line = type_def.end_line + 1;

        // Allow at most one blank line between type def and impl
        if impl_start_line > expected_line + 1 {
            let gap = impl_start_line - type_def.end_line - 1;
            violations.push(Violation {
                rule: RULE,
                file: path_str.clone(),
                line: impl_start_line,
                message: format!(
                    "`impl {}` should follow type definition (line {}), but has {} blank line(s)",
                    type_name, type_def.end_line, gap
                ),
            });
        }

        // Update end_line so next impl must follow this one
        type_defs.insert(type_name, TypeDef { end_line: impl_block.span().end().line });
    }

    violations
}

fn check_file(path: &Path) -> Result<Vec<Violation>, String> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| format!("Failed to read {}: {}", path.display(), e))?;

    let file = syn::parse_file(&content)
        .map_err(|e| format!("Failed to parse {}: {}", path.display(), e))?;

    let mut violations = Vec::new();

    // Run all checks
    violations.extend(check_impl_follows_type(path, &file));

    Ok(violations)
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();

    let paths: Vec<PathBuf> = if args.len() > 1 {
        args[1..].iter().map(PathBuf::from).collect()
    } else {
        find_src_dirs(Path::new("."))
    };

    if paths.is_empty() {
        eprintln!("No source directories found.");
        return ExitCode::FAILURE;
    }

    let mut all_violations = Vec::new();

    for path in paths {
        let walker = WalkDir::new(&path)
            .into_iter()
            .filter_entry(|e| {
                let name = e.file_name().to_string_lossy();
                !name.starts_with('.') && name != "target" && name != "libs"
            });

        for entry in walker.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.extension().is_some_and(|ext| ext == "rs") {
                match check_file(path) {
                    Ok(violations) => all_violations.extend(violations),
                    Err(e) => eprintln!("Warning: {}", e),
                }
            }
        }
    }

    if all_violations.is_empty() {
        println!("rust_style: all checks passed");
        ExitCode::SUCCESS
    } else {
        eprintln!("rust_style: found {} violation(s):\n", all_violations.len());
        for v in &all_violations {
            eprintln!("  [{}] {}:{}: {}", v.rule, v.file, v.line, v.message);
        }
        ExitCode::FAILURE
    }
}
