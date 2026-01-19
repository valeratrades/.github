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
#! nix in pkgs.mkShell {
#! nix   buildInputs = [ toolchain pkgs.nix ];
#! nix }
#! nix ``
#! nix --command sh -c ``cargo -Zscript -q "$0" "$@"``

[package]
edition = "2024"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
ureq = { version = "2", features = ["json"] }
regex = "1"
---

//! Bump crate versions in v-utils flake.
//!
//! Usage:
//!   bump_crate.rs --crate "name:mode" [--crate "name:mode" ...] --version-var-postfix "Postfix"
//!
//! Modes:
//!   binstall - Only update version variable (for crates installed via cargo-binstall)
//!   source   - Update version and verify build with nix (for crates built from source)
//!
//! Examples:
//!   bump_crate.rs --crate "tracey:binstall" --crate "codestyle:binstall" --version-var-postfix "Version"
//!   bump_crate.rs --crate "tracey:source" --version-var-postfix "Version"

use regex::Regex;
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, ExitCode};

#[derive(Debug, Deserialize)]
struct CrateResponse {
    #[serde(rename = "crate")]
    krate: CrateInfo,
}

#[derive(Debug, Deserialize)]
struct CrateInfo {
    newest_version: String,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum InstallMode {
    Binstall,
    Source,
}

#[derive(Debug)]
struct CrateConfig {
    name: String,
    version_var: String,
    mode: InstallMode,
}

fn parse_args() -> Result<(Vec<CrateConfig>, String), String> {
    let args: Vec<String> = env::args().collect();
    let mut crates = Vec::new();
    let mut version_var_postfix = None;
    let mut i = 1;

    while i < args.len() {
        match args[i].as_str() {
            "--help" | "-h" => {
                return Err("help".to_string());
            }
            "--crate" => {
                i += 1;
                if i >= args.len() {
                    return Err("--crate requires an argument".to_string());
                }
                let spec = &args[i];
                let parts: Vec<&str> = spec.split(':').collect();
                if parts.len() != 2 {
                    return Err(format!("Invalid crate spec '{}': expected 'name:mode'", spec));
                }
                let name = parts[0].to_string();
                let mode = match parts[1] {
                    "binstall" => InstallMode::Binstall,
                    "source" => InstallMode::Source,
                    other => return Err(format!("Unknown mode '{}': expected 'binstall' or 'source'", other)),
                };
                crates.push((name, mode));
            }
            "--version-var-postfix" => {
                i += 1;
                if i >= args.len() {
                    return Err("--version-var-postfix requires an argument".to_string());
                }
                version_var_postfix = Some(args[i].clone());
            }
            other => {
                return Err(format!("Unknown argument: {}", other));
            }
        }
        i += 1;
    }

    let postfix = version_var_postfix.ok_or_else(|| "--version-var-postfix is required".to_string())?;

    if crates.is_empty() {
        return Err("At least one --crate argument is required".to_string());
    }

    let configs: Vec<CrateConfig> = crates
        .into_iter()
        .map(|(name, mode)| {
            let version_var = format!("{}{}", name, postfix);
            CrateConfig { name, version_var, mode }
        })
        .collect();

    Ok((configs, postfix))
}

fn get_latest_version(crate_name: &str) -> Result<String, String> {
    let url = format!("https://crates.io/api/v1/crates/{}", crate_name);
    let response: CrateResponse = ureq::get(&url)
        .set("User-Agent", "v-utils-bump-crate/1.0")
        .call()
        .map_err(|e| format!("Failed to fetch {}: {}", crate_name, e))?
        .into_json()
        .map_err(|e| format!("Failed to parse response: {}", e))?;
    Ok(response.krate.newest_version)
}

fn get_current_version(content: &str, version_var: &str) -> Option<String> {
    let pattern = format!(r#"{} = "([^"]+)""#, regex::escape(version_var));
    let re = Regex::new(&pattern).ok()?;
    re.captures(content).map(|c| c[1].to_string())
}

fn update_version(content: &str, version_var: &str, new_version: &str) -> String {
    let pattern = format!(r#"({} = ")[^"]+(")"#, regex::escape(version_var));
    let re = Regex::new(&pattern).unwrap();
    re.replace_all(content, format!("${{1}}{}${{2}}", new_version)).to_string()
}

fn get_src_hash(crate_name: &str, version: &str) -> Result<String, String> {
    let url = format!("https://crates.io/api/v1/crates/{}/{}/download", crate_name, version);
    let output = Command::new("nix-prefetch-url")
        .args(["--unpack", &url])
        .output()
        .map_err(|e| format!("Failed to run nix-prefetch-url: {}", e))?;

    if !output.status.success() {
        return Err(format!("nix-prefetch-url failed: {}", String::from_utf8_lossy(&output.stderr)));
    }

    let hash = String::from_utf8_lossy(&output.stdout).trim().to_string();

    // Convert to SRI format
    let output = Command::new("nix")
        .args(["hash", "convert", "--hash-algo", "sha256", "--to", "sri", &hash])
        .output()
        .map_err(|e| format!("Failed to convert hash: {}", e))?;

    if !output.status.success() {
        return Err(format!("nix hash convert failed: {}", String::from_utf8_lossy(&output.stderr)));
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn update_src_hash(content: &str, crate_name: &str, new_hash: &str) -> String {
    // Find the fetchCrate block for this crate and update its hash
    // Pattern: pname = "crate_name"; ... hash = "old_hash";
    let pattern = format!(
        r#"(pname = "{}";\s+version = [^;]+;\s+hash = ")[^"]+(")"#,
        regex::escape(crate_name)
    );
    let re = Regex::new(&pattern).unwrap();
    re.replace(content, format!("${{1}}{}${{2}}", new_hash)).to_string()
}

// NB: Must match the pinned nightly in rs/default.nix
const CODESTYLE_NIGHTLY: &str = "2025-10-10";

fn get_cargo_hash_from_build_error(crate_name: &str, version: &str, src_hash: &str, repo_root: &Path) -> Option<String> {
    // Build a minimal nix expression that uses fetchCargoVendor with a fake hash
    // to get the correct hash from the error message
    let nightly_date = if crate_name == "codestyle" { CODESTYLE_NIGHTLY } else { "latest" };
    let nix_expr = format!(
        r#"
        let
          rust_flake = builtins.getFlake "github:oxalica/rust-overlay";
          nixpkgs_flake = builtins.getFlake "nixpkgs";
          pkgs = import nixpkgs_flake {{
            system = builtins.currentSystem;
            overlays = [ rust_flake.overlays.default ];
          }};
          nightlyRust = pkgs.rust-bin.nightly."{nightly_date}".default;
          nightlyPlatform = pkgs.makeRustPlatform {{
            rustc = nightlyRust;
            cargo = nightlyRust;
          }};
        in
        nightlyPlatform.buildRustPackage {{
          pname = "{crate_name}";
          version = "{version}";
          src = pkgs.fetchCrate {{
            pname = "{crate_name}";
            version = "{version}";
            hash = "{src_hash}";
          }};
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          doCheck = false;
        }}
        "#,
        nightly_date = nightly_date,
        crate_name = crate_name,
        version = version,
        src_hash = src_hash
    );

    let output = Command::new("nix-build")
        .args(["--impure", "--expr", &nix_expr])
        .current_dir(repo_root)
        .output()
        .ok()?;

    let stderr = String::from_utf8_lossy(&output.stderr);
    // Look for "got:    sha256-..." line
    for line in stderr.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("got:") {
            let hash = trimmed.strip_prefix("got:")?.trim();
            if hash.starts_with("sha256-") {
                return Some(hash.to_string());
            }
        }
    }
    None
}

fn update_cargo_hash(content: &str, crate_name: &str, new_hash: &str) -> String {
    // Find cargoHash after the pname = "crate_name" block
    // This is trickier - we need to find the right cargoHash
    let lines: Vec<&str> = content.lines().collect();
    let mut result = Vec::new();
    let mut in_crate_block = false;
    let mut found_cargo_hash = false;

    for line in lines {
        if line.contains(&format!("pname = \"{}\"", crate_name)) {
            in_crate_block = true;
        }

        if in_crate_block && !found_cargo_hash && line.contains("cargoHash = ") {
            let re = Regex::new(r#"cargoHash = "[^"]+""#).unwrap();
            let new_line = re.replace(line, format!("cargoHash = \"{}\"", new_hash));
            result.push(new_line.to_string());
            found_cargo_hash = true;
            in_crate_block = false;
            continue;
        }

        result.push(line.to_string());
    }

    result.join("\n")
}

/// Extract major.minor from a version string (e.g., "0.2.22" -> "0.2")
fn to_partial_semver(version: &str) -> String {
    let parts: Vec<&str> = version.split('.').collect();
    if parts.len() >= 2 {
        format!("{}.{}", parts[0], parts[1])
    } else {
        version.to_string()
    }
}

fn bump_crate_binstall(crate_cfg: &CrateConfig, repo_root: &Path) -> Result<bool, String> {
    println!("Checking {} (binstall)...", crate_cfg.name);

    let latest_full = get_latest_version(&crate_cfg.name)?;
    let latest = to_partial_semver(&latest_full);
    println!("  Latest version: {} (partial: {})", latest_full, latest);

    let flake_path = repo_root.join("flake.nix");
    let rs_path = repo_root.join("rs/default.nix");

    let flake_content = fs::read_to_string(&flake_path)
        .map_err(|e| format!("Failed to read flake.nix: {}", e))?;
    let rs_content = fs::read_to_string(&rs_path)
        .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;

    let current = get_current_version(&flake_content, &crate_cfg.version_var)
        .ok_or_else(|| format!("Could not find {} in flake.nix", crate_cfg.version_var))?;
    println!("  Current version: {}", current);

    if current == latest {
        println!("  Already up to date!");
        return Ok(false);
    }

    println!("  Updating {} -> {}...", current, latest);

    // For binstall mode, use partial semver (major.minor only).
    // cargo-binstall resolves to the latest matching patch version.
    let flake_content = update_version(&flake_content, &crate_cfg.version_var, &latest);
    let rs_content = update_version(&rs_content, &crate_cfg.version_var, &latest);

    fs::write(&flake_path, &flake_content)
        .map_err(|e| format!("Failed to write flake.nix: {}", e))?;
    fs::write(&rs_path, &rs_content)
        .map_err(|e| format!("Failed to write rs/default.nix: {}", e))?;

    println!("  SUCCESS: {} updated to {}", crate_cfg.name, latest);
    Ok(true)
}

fn bump_crate_source(crate_cfg: &CrateConfig, repo_root: &Path) -> Result<bool, String> {
    println!("Checking {} (source)...", crate_cfg.name);

    let latest = get_latest_version(&crate_cfg.name)?;
    println!("  Latest version: {}", latest);

    let flake_path = repo_root.join("flake.nix");
    let rs_path = repo_root.join("rs/default.nix");

    let flake_content = fs::read_to_string(&flake_path)
        .map_err(|e| format!("Failed to read flake.nix: {}", e))?;
    let rs_content = fs::read_to_string(&rs_path)
        .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;

    let current = get_current_version(&flake_content, &crate_cfg.version_var)
        .ok_or_else(|| format!("Could not find {} in flake.nix", crate_cfg.version_var))?;
    println!("  Current version: {}", current);

    if current == latest {
        println!("  Already up to date!");
        return Ok(false);
    }

    println!("  Updating {} -> {}...", current, latest);

    // Get new source hash
    println!("  Fetching source hash...");
    let src_hash = get_src_hash(&crate_cfg.name, &latest)?;
    println!("  Source hash: {}", src_hash);

    // Update versions
    let flake_content = update_version(&flake_content, &crate_cfg.version_var, &latest);
    let rs_content = update_version(&rs_content, &crate_cfg.version_var, &latest);

    // Update source hash
    let rs_content = update_src_hash(&rs_content, &crate_cfg.name, &src_hash);

    // Write updates
    fs::write(&flake_path, &flake_content)
        .map_err(|e| format!("Failed to write flake.nix: {}", e))?;
    fs::write(&rs_path, &rs_content)
        .map_err(|e| format!("Failed to write rs/default.nix: {}", e))?;

    // Try to build to get cargoHash
    println!("  Building to determine cargoHash (will fail once)...");
    if let Some(cargo_hash) = get_cargo_hash_from_build_error(&crate_cfg.name, &latest, &src_hash, repo_root) {
        println!("  New cargoHash: {}", cargo_hash);
        let rs_content = fs::read_to_string(&rs_path)
            .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;
        let rs_content = update_cargo_hash(&rs_content, &crate_cfg.name, &cargo_hash);
        fs::write(&rs_path, rs_content)
            .map_err(|e| format!("Failed to write rs/default.nix: {}", e))?;
    }

    // Verify build by actually building the crate with the updated hashes
    println!("  Verifying build...");

    // Read the updated rs/default.nix to get the new cargoHash
    let rs_content = fs::read_to_string(&rs_path)
        .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;

    // Extract cargoHash from the file
    let cargo_hash = {
        let lines: Vec<&str> = rs_content.lines().collect();
        let mut in_crate_block = false;
        let mut found_hash = None;
        for line in lines {
            if line.contains(&format!("pname = \"{}\"", crate_cfg.name)) {
                in_crate_block = true;
            }
            if in_crate_block && line.contains("cargoHash = ") {
                let re = Regex::new(r#"cargoHash = "([^"]+)""#).unwrap();
                if let Some(caps) = re.captures(line) {
                    found_hash = Some(caps[1].to_string());
                }
                break;
            }
        }
        found_hash.ok_or_else(|| "Could not find cargoHash in rs/default.nix".to_string())?
    };

    // Build a verification expression
    let nightly_date = if crate_cfg.name == "codestyle" { CODESTYLE_NIGHTLY } else { "latest" };
    let verify_expr = format!(
        r#"
        let
          rust_flake = builtins.getFlake "github:oxalica/rust-overlay";
          nixpkgs_flake = builtins.getFlake "nixpkgs";
          pkgs = import nixpkgs_flake {{
            system = builtins.currentSystem;
            overlays = [ rust_flake.overlays.default ];
          }};
          nightlyRust = pkgs.rust-bin.nightly."{nightly_date}".default;
          nightlyPlatform = pkgs.makeRustPlatform {{
            rustc = nightlyRust;
            cargo = nightlyRust;
          }};
        in
        nightlyPlatform.buildRustPackage {{
          pname = "{crate_name}";
          version = "{version}";
          src = pkgs.fetchCrate {{
            pname = "{crate_name}";
            version = "{version}";
            hash = "{src_hash}";
          }};
          cargoHash = "{cargo_hash}";
          doCheck = false;
        }}
        "#,
        nightly_date = nightly_date,
        crate_name = crate_cfg.name,
        version = latest,
        src_hash = src_hash,
        cargo_hash = cargo_hash
    );

    let status = Command::new("nix-build")
        .args(["--impure", "--expr", &verify_expr, "--no-out-link"])
        .current_dir(repo_root)
        .status()
        .map_err(|e| format!("Failed to run nix-build: {}", e))?;

    if status.success() {
        println!("  SUCCESS: {} updated to {}", crate_cfg.name, latest);
        Ok(true)
    } else {
        Err(format!("Build failed after update, may need manual intervention"))
    }
}

fn bump_crate(crate_cfg: &CrateConfig, repo_root: &Path) -> Result<bool, String> {
    match crate_cfg.mode {
        InstallMode::Binstall => bump_crate_binstall(crate_cfg, repo_root),
        InstallMode::Source => bump_crate_source(crate_cfg, repo_root),
    }
}

fn print_usage() {
    eprintln!("Usage: bump_crate.rs --crate \"name:mode\" [--crate ...] --version-var-postfix \"Postfix\"");
    eprintln!();
    eprintln!("Modes:");
    eprintln!("  binstall - Only update version variable (for crates installed via cargo-binstall)");
    eprintln!("  source   - Update version and verify build with nix (for crates built from source)");
    eprintln!();
    eprintln!("Examples:");
    eprintln!("  bump_crate.rs --crate \"tracey:binstall\" --crate \"codestyle:binstall\" --version-var-postfix \"Version\"");
    eprintln!("  bump_crate.rs --crate \"tracey:source\" --version-var-postfix \"Version\"");
}

fn main() -> ExitCode {
    let (crates, _postfix) = match parse_args() {
        Ok(result) => result,
        Err(e) if e == "help" => {
            print_usage();
            return ExitCode::from(0);
        }
        Err(e) => {
            eprintln!("ERROR: {}", e);
            eprintln!();
            print_usage();
            return ExitCode::from(1);
        }
    };

    // Find repo root (directory containing flake.nix)
    let mut repo_root = env::current_dir().expect("Failed to get current directory");
    while !repo_root.join("flake.nix").exists() {
        if !repo_root.pop() {
            eprintln!("ERROR: Could not find flake.nix in any parent directory");
            return ExitCode::from(1);
        }
    }

    let mut any_updated = false;
    let mut any_failed = false;

    for crate_cfg in &crates {
        match bump_crate(crate_cfg, &repo_root) {
            Ok(updated) => any_updated |= updated,
            Err(e) => {
                eprintln!("ERROR bumping {}: {}", crate_cfg.name, e);
                any_failed = true;
            }
        }
    }

    if any_failed {
        ExitCode::from(1)
    } else if any_updated {
        println!("\nDone! Don't forget to test and commit the changes.");
        ExitCode::from(0)
    } else {
        println!("\nAll crates are up to date.");
        ExitCode::from(0)
    }
}
