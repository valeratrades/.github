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
syn = { version = "2", features = ["full", "parsing", "visit"] }
proc-macro2 = { version = "1", features = ["span-locations"] }
quote = "1"
walkdir = "2"
---

//! Custom Rust style checks beyond what rustfmt and clippy provide.
//!
//! Usage:
//!   rust_style [command] [options] [paths...]
//!
//! Commands:
//!   assert  - Check for violations and error on any mismatches (default)
//!   format  - Attempt to fix violations automatically (warns on unfixable)
//!
//! Options:
//!   --impl-follows-type=true|false  - Check impl blocks follow type defs (default: true)
//!   --embed-simple-vars=true|false  - Check simple vars are embedded in format strings (default: true)

use proc_macro2::{Span, TokenStream, TokenTree};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use syn::spanned::Spanned;
use syn::visit::Visit;
use syn::{ExprMacro, Item, ItemEnum, ItemStruct, ItemUnion, Macro};
use walkdir::WalkDir;

const FORMAT_MACROS: &[&str] = &[
    "format",
    "write",
    "writeln",
    "print",
    "println",
    "eprint",
    "eprintln",
    "panic",
    "format_args",
    "log",
    "trace",
    "debug",
    "info",
    "warn",
    "error",
];

#[derive(Clone, Copy, PartialEq, Eq)]
enum Command {
    Assert,
    Format,
}

#[derive(Clone)]
struct Config {
    command: Command,
    impl_follows_type: bool,
    embed_simple_vars: bool,
}
impl Default for Config {
    fn default() -> Self {
        Self {
            command: Command::Assert,
            impl_follows_type: true,
            embed_simple_vars: true,
        }
    }
}

#[derive(Clone)]
struct Violation {
    rule: &'static str,
    file: String,
    line: usize,
    message: String,
    fix: Option<Fix>,
}

#[derive(Clone)]
struct Fix {
    start_byte: usize,
    end_byte: usize,
    replacement: String,
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

    let mut in_workspace = false;
    let mut members = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed == "[workspace]" {
            in_workspace = true;
        } else if trimmed.starts_with('[') && trimmed != "[workspace]" {
            in_workspace = false;
        } else if in_workspace
            && trimmed.starts_with("members")
            && let Some(start) = line.find('[')
        {
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

    for item in &file.items {
        let (name, end_line) = match item {
            Item::Struct(ItemStruct { ident, .. }) => (ident.to_string(), item.span().end().line),
            Item::Enum(ItemEnum { ident, .. }) => (ident.to_string(), item.span().end().line),
            Item::Union(ItemUnion { ident, .. }) => (ident.to_string(), item.span().end().line),
            _ => continue,
        };

        type_defs.insert(name, TypeDef { end_line });
    }

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

        if impl_block.trait_.is_some() {
            continue;
        }

        let Some(type_def) = type_defs.get(&type_name) else {
            continue;
        };

        let impl_start_line = impl_block.span().start().line;
        let expected_line = type_def.end_line + 1;

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
                fix: None,
            });
        }

        type_defs.insert(
            type_name,
            TypeDef {
                end_line: impl_block.span().end().line,
            },
        );
    }

    violations
}

/// Visitor to find format macro invocations
struct FormatMacroVisitor<'a> {
    path_str: String,
    content: &'a str,
    violations: Vec<Violation>,
    seen_spans: std::collections::HashSet<(usize, usize)>, // (start_line, start_col) to dedupe
}

impl<'a> FormatMacroVisitor<'a> {
    fn new(path: &Path, content: &'a str) -> Self {
        Self {
            path_str: path.display().to_string(),
            content,
            violations: Vec::new(),
            seen_spans: std::collections::HashSet::new(),
        }
    }

    fn check_format_macro(&mut self, mac: &Macro) {
        // Deduplicate based on span start position
        let start = mac.span().start();
        let key = (start.line, start.column);
        if self.seen_spans.contains(&key) {
            return;
        }
        self.seen_spans.insert(key);
        // Check if this is a format-like macro
        let macro_name = mac
            .path
            .segments
            .last()
            .map(|s| s.ident.to_string())
            .unwrap_or_default();

        if !FORMAT_MACROS.contains(&macro_name.as_str()) {
            return;
        }

        // Parse the macro tokens to find format string and arguments
        self.analyze_format_macro_tokens(&mac.tokens);
    }

    fn analyze_format_macro_tokens(&mut self, tokens: &TokenStream) {
        let tokens: Vec<TokenTree> = tokens.clone().into_iter().collect();

        // Find the format string (first string literal)
        let mut format_string_idx = None;
        let mut format_string_content = String::new();
        let mut format_string_span: Option<Span> = None;

        for (i, token) in tokens.iter().enumerate() {
            if let TokenTree::Literal(lit) = token {
                let lit_str = lit.to_string();
                // Check if it's a string literal (starts and ends with ")
                if lit_str.starts_with('"') || lit_str.starts_with("r#") || lit_str.starts_with("r\"") {
                    format_string_idx = Some(i);
                    format_string_content = lit_str;
                    format_string_span = Some(lit.span());
                    break;
                }
            }
        }

        let Some(fmt_idx) = format_string_idx else {
            return;
        };
        let Some(fmt_span) = format_string_span else {
            return;
        };

        // Count empty placeholders {} in the format string
        let empty_placeholder_count = count_empty_placeholders(&format_string_content);
        if empty_placeholder_count == 0 {
            return;
        }

        // Collect the arguments after the format string
        let mut args: Vec<(String, Span)> = Vec::new();
        let mut i = fmt_idx + 1;

        while i < tokens.len() {
            // Skip commas
            if let TokenTree::Punct(p) = &tokens[i] {
                if p.as_char() == ',' {
                    i += 1;
                    continue;
                }
            }

            // Collect the next argument (could be a single ident or more complex)
            if let Some((arg_str, arg_span, next_i)) = collect_argument(&tokens, i) {
                args.push((arg_str, arg_span));
                i = next_i;
            } else {
                i += 1;
            }
        }

        // Check if we have simple identifiers that could be embedded
        // We need to match empty placeholders with their corresponding arguments
        let placeholder_positions = find_empty_placeholder_positions(&format_string_content);

        if placeholder_positions.len() != args.len() {
            // Mismatch - can't safely fix
            return;
        }

        // Check which arguments are simple identifiers
        let simple_args: Vec<(usize, &str, Span)> = placeholder_positions
            .iter()
            .zip(args.iter())
            .filter_map(|(pos, (arg_str, arg_span))| {
                if is_simple_identifier(arg_str) {
                    Some((*pos, arg_str.as_str(), *arg_span))
                } else {
                    None
                }
            })
            .collect();

        if simple_args.is_empty() {
            return;
        }

        // If ALL args are simple identifiers, we can auto-fix the entire macro
        let all_simple = simple_args.len() == args.len();

        let fix = if all_simple {
            // Build the new format string with all vars embedded
            let mut new_fmt = format_string_content.clone();
            // Replace from end to start to preserve positions
            for (pos, arg_str, _) in simple_args.iter().rev() {
                // pos points to '{' in "{}", so we replace 2 chars with {var_name}
                let end_pos = pos + 2; // After '}'
                new_fmt.replace_range(*pos..end_pos, &format!("{{{}}}", arg_str));
            }

            // Calculate byte offsets in the original file
            // This is complex because we need the actual file positions
            create_full_macro_fix(&format_string_content, &new_fmt, fmt_span, self.content)
        } else {
            None
        };

        // Report violations for each simple arg
        for (_, arg_str, arg_span) in &simple_args {
            self.violations.push(Violation {
                rule: "embed-simple-vars",
                file: self.path_str.clone(),
                line: arg_span.start().line,
                message: format!(
                    "variable `{}` should be embedded in format string: use `{{{}}}` instead of `{{}}, {}`",
                    arg_str, arg_str, arg_str
                ),
                fix: fix.clone(),
            });
        }
    }
}

impl<'a> Visit<'a> for FormatMacroVisitor<'a> {
    fn visit_expr_macro(&mut self, node: &'a ExprMacro) {
        self.check_format_macro(&node.mac);
        syn::visit::visit_expr_macro(self, node);
    }

    fn visit_macro(&mut self, node: &'a Macro) {
        self.check_format_macro(node);
        syn::visit::visit_macro(self, node);
    }
}

/// Count the number of empty {} placeholders in a format string
fn count_empty_placeholders(format_str: &str) -> usize {
    let mut count = 0;
    let mut chars = format_str.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '{' {
            if let Some(&next) = chars.peek() {
                if next == '{' {
                    // Escaped brace {{
                    chars.next();
                } else if next == '}' {
                    // Empty placeholder {}
                    count += 1;
                    chars.next();
                } else {
                    // Named or formatted placeholder, skip until }
                    while let Some(c) = chars.next() {
                        if c == '}' {
                            break;
                        }
                    }
                }
            }
        }
    }

    count
}

/// Find byte positions of empty {} placeholders within the format string content
fn find_empty_placeholder_positions(format_str: &str) -> Vec<usize> {
    let mut positions = Vec::new();
    let mut chars = format_str.char_indices().peekable();

    while let Some((idx, c)) = chars.next() {
        if c == '{' {
            if let Some(&(_, next)) = chars.peek() {
                if next == '{' {
                    chars.next();
                } else if next == '}' {
                    positions.push(idx);
                    chars.next();
                } else {
                    while let Some((_, c)) = chars.next() {
                        if c == '}' {
                            break;
                        }
                    }
                }
            }
        }
    }

    positions
}

/// Check if a string is a simple identifier (alphanumeric + underscore, not starting with digit)
fn is_simple_identifier(s: &str) -> bool {
    if s.is_empty() {
        return false;
    }

    let mut chars = s.chars();
    let first = chars.next().unwrap();

    if !first.is_alphabetic() && first != '_' {
        return false;
    }

    chars.all(|c| c.is_alphanumeric() || c == '_')
}

/// Collect an argument from the token stream, handling grouped tokens
fn collect_argument(tokens: &[TokenTree], start: usize) -> Option<(String, Span, usize)> {
    if start >= tokens.len() {
        return None;
    }

    let first = &tokens[start];

    // If it's a simple identifier, return it
    if let TokenTree::Ident(ident) = first {
        // Check if next token makes this a complex expression (., ::, etc.)
        if start + 1 < tokens.len() {
            if let TokenTree::Punct(p) = &tokens[start + 1] {
                let ch = p.as_char();
                if ch == '.' || ch == ':' {
                    // Complex expression - collect until comma or end
                    return collect_complex_argument(tokens, start);
                }
            }
        }
        return Some((ident.to_string(), ident.span(), start + 1));
    }

    // For anything else, collect as complex argument
    collect_complex_argument(tokens, start)
}

/// Collect a complex argument (method call, field access, etc.)
fn collect_complex_argument(tokens: &[TokenTree], start: usize) -> Option<(String, Span, usize)> {
    let mut result = String::new();
    let mut i = start;
    let start_span = tokens.get(start)?.span();
    let mut depth = 0;

    while i < tokens.len() {
        let token = &tokens[i];

        match token {
            TokenTree::Punct(p) if p.as_char() == ',' && depth == 0 => {
                break;
            }
            TokenTree::Group(g) => {
                depth += 1;
                result.push_str(&g.to_string());
                depth -= 1;
            }
            _ => {
                result.push_str(&token.to_string());
            }
        }

        i += 1;
    }

    if result.is_empty() {
        None
    } else {
        Some((result.trim().to_string(), start_span, i))
    }
}

/// Create a fix that embeds variables in the format string and removes args
/// Returns None if the fix is too complex (multiline, etc.)
fn create_full_macro_fix(
    old_fmt: &str,
    new_fmt: &str,
    fmt_span: Span,
    content: &str,
) -> Option<Fix> {
    // Only fix single-line format strings for now
    if fmt_span.start().line != fmt_span.end().line {
        return None;
    }

    // Get the line containing the format string
    let lines: Vec<&str> = content.lines().collect();
    let line_idx = fmt_span.start().line - 1; // 0-indexed
    if line_idx >= lines.len() {
        return None;
    }
    let line = lines[line_idx];

    // Find the old format string in this line
    let Some(fmt_pos) = line.find(old_fmt) else {
        return None;
    };

    // After the format string, we expect ", arg1, arg2, ..." pattern up to closing )
    let after_fmt = &line[fmt_pos + old_fmt.len()..];

    // Count how many simple args we're embedding (number of {} in old that become {var})
    let old_placeholder_count = count_empty_placeholders(old_fmt);

    // Find the args and the closing paren
    let mut depth = 0;
    let mut args_end = None;
    let mut comma_count = 0;
    let mut in_string = false;
    let mut escape_next = false;

    for (i, ch) in after_fmt.char_indices() {
        if escape_next {
            escape_next = false;
            continue;
        }
        match ch {
            '\\' if in_string => escape_next = true,
            '"' => in_string = !in_string,
            '(' | '[' | '{' if !in_string => depth += 1,
            ')' if !in_string => {
                if depth == 0 {
                    args_end = Some(i);
                    break;
                }
                depth -= 1;
            }
            ']' | '}' if !in_string && depth > 0 => depth -= 1,
            ',' if !in_string && depth == 0 => comma_count += 1,
            _ => {}
        }
    }

    let args_end_pos = args_end?;

    // comma_count should match old_placeholder_count (one comma before each arg)
    if comma_count != old_placeholder_count {
        return None;
    }

    // Build the new line: everything before fmt + new_fmt + closing paren + rest
    let before_fmt = &line[..fmt_pos];
    let after_args = &after_fmt[args_end_pos..]; // starts with the closing )

    let new_line = format!("{}{}{}", before_fmt, new_fmt, after_args);

    // Calculate byte offset for this line
    let mut line_start_byte = 0;
    for (i, l) in lines.iter().enumerate() {
        if i == line_idx {
            break;
        }
        line_start_byte += l.len() + 1; // +1 for newline
    }

    Some(Fix {
        start_byte: line_start_byte,
        end_byte: line_start_byte + line.len(),
        replacement: new_line,
    })
}

/// Check: simple variables should be embedded in format strings
fn check_embed_simple_vars(path: &Path, content: &str, file: &syn::File) -> Vec<Violation> {
    let mut visitor = FormatMacroVisitor::new(path, content);
    visitor.visit_file(file);
    visitor.violations
}

fn check_file(path: &Path, config: &Config) -> Result<Vec<Violation>, String> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| format!("Failed to read {}: {}", path.display(), e))?;

    let file = syn::parse_file(&content)
        .map_err(|e| format!("Failed to parse {}: {}", path.display(), e))?;

    let mut violations = Vec::new();

    if config.impl_follows_type {
        violations.extend(check_impl_follows_type(path, &file));
    }

    if config.embed_simple_vars {
        violations.extend(check_embed_simple_vars(path, &content, &file));
    }

    Ok(violations)
}

fn apply_fixes(violations: &[Violation]) -> (usize, usize) {
    let mut fixes_by_file: HashMap<String, Vec<&Fix>> = HashMap::new();

    for v in violations {
        if let Some(ref fix) = v.fix {
            fixes_by_file.entry(v.file.clone()).or_default().push(fix);
        }
    }

    let mut fixed_count = 0;
    let mut unfixable_count = 0;

    for (file_path, fixes) in fixes_by_file {
        let content = match std::fs::read_to_string(&file_path) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("Warning: Failed to read {} for fixing: {}", file_path, e);
                unfixable_count += fixes.len();
                continue;
            }
        };

        // Deduplicate fixes by (start_byte, end_byte) - same position means same fix
        let mut seen_positions = std::collections::HashSet::new();
        let mut unique_fixes: Vec<&Fix> = Vec::new();
        for fix in fixes {
            let key = (fix.start_byte, fix.end_byte);
            if !seen_positions.contains(&key) {
                seen_positions.insert(key);
                unique_fixes.push(fix);
            }
        }

        // Sort fixes by start position (descending) to apply from end to beginning
        unique_fixes.sort_by(|a, b| b.start_byte.cmp(&a.start_byte));

        let mut new_content = content.clone();

        for fix in unique_fixes {
            if fix.start_byte <= new_content.len() && fix.end_byte <= new_content.len() {
                new_content.replace_range(fix.start_byte..fix.end_byte, &fix.replacement);
                fixed_count += 1;
            } else {
                unfixable_count += 1;
            }
        }

        if let Err(e) = std::fs::write(&file_path, new_content) {
            eprintln!("Warning: Failed to write {}: {}", file_path, e);
        }
    }

    for v in violations {
        if v.fix.is_none() {
            unfixable_count += 1;
        }
    }

    (fixed_count, unfixable_count)
}

fn parse_bool_flag(value: &str) -> Option<bool> {
    match value.to_lowercase().as_str() {
        "true" | "1" | "yes" => Some(true),
        "false" | "0" | "no" => Some(false),
        _ => None,
    }
}

fn print_usage() {
    eprintln!(
        r#"rust_style - Custom Rust style checks

Usage:
  rust_style [command] [options] [paths...]

Commands:
  assert  - Check for violations and error on any mismatches (default)
  format  - Attempt to fix violations automatically (warns on unfixable)

Options:
  --impl-follows-type=true|false  - Check impl blocks follow type defs (default: true)
  --embed-simple-vars=true|false  - Check simple vars are embedded in format strings (default: true)
  --help                          - Show this help message

Examples:
  rust_style                      # Assert mode on current directory
  rust_style format               # Format mode on current directory
  rust_style assert ./src         # Assert mode on specific path
  rust_style --embed-simple-vars=false ./src  # Disable a specific check
"#
    );
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();

    let mut config = Config::default();
    let mut paths: Vec<PathBuf> = Vec::new();

    let mut i = 1;
    while i < args.len() {
        let arg = &args[i];

        if arg == "--help" || arg == "-h" {
            print_usage();
            return ExitCode::SUCCESS;
        } else if arg == "assert" {
            config.command = Command::Assert;
        } else if arg == "format" {
            config.command = Command::Format;
        } else if let Some(value) = arg.strip_prefix("--impl-follows-type=") {
            match parse_bool_flag(value) {
                Some(v) => config.impl_follows_type = v,
                None => {
                    eprintln!("Invalid value for --impl-follows-type: {}", value);
                    return ExitCode::FAILURE;
                }
            }
        } else if let Some(value) = arg.strip_prefix("--embed-simple-vars=") {
            match parse_bool_flag(value) {
                Some(v) => config.embed_simple_vars = v,
                None => {
                    eprintln!("Invalid value for --embed-simple-vars: {}", value);
                    return ExitCode::FAILURE;
                }
            }
        } else if arg.starts_with('-') {
            eprintln!("Unknown option: {}", arg);
            print_usage();
            return ExitCode::FAILURE;
        } else {
            paths.push(PathBuf::from(arg));
        }

        i += 1;
    }

    if paths.is_empty() {
        paths = find_src_dirs(Path::new("."));
    }

    if paths.is_empty() {
        eprintln!("No source directories found.");
        return ExitCode::FAILURE;
    }

    let mut all_violations = Vec::new();

    for path in paths {
        let walker = WalkDir::new(&path).into_iter().filter_entry(|e| {
            let name = e.file_name().to_string_lossy();
            !name.starts_with('.') && name != "target" && name != "libs"
        });

        for entry in walker.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.extension().is_some_and(|ext| ext == "rs") {
                match check_file(path, &config) {
                    Ok(violations) => all_violations.extend(violations),
                    Err(e) => eprintln!("Warning: {}", e),
                }
            }
        }
    }

    match config.command {
        Command::Assert => {
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
        Command::Format => {
            if all_violations.is_empty() {
                println!("rust_style: all checks passed, nothing to format");
                ExitCode::SUCCESS
            } else {
                let (fixed, unfixable) = apply_fixes(&all_violations);

                if fixed > 0 {
                    println!("rust_style: fixed {} violation(s)", fixed);
                }

                if unfixable > 0 {
                    eprintln!(
                        "rust_style: {} violation(s) need manual fixing:\n",
                        unfixable
                    );
                    for v in &all_violations {
                        if v.fix.is_none() {
                            eprintln!("  [{}] {}:{}: {}", v.rule, v.file, v.line, v.message);
                        }
                    }
                    ExitCode::FAILURE
                } else {
                    ExitCode::SUCCESS
                }
            }
        }
    }
}
