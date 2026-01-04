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

//! Bump crate versions and hashes in v-utils flake.
//!
//! Usage:
//!   bump_crate.rs <crate-name>
//!   bump_crate.rs --all
//!
//! Examples:
//!   bump_crate.rs codestyle
//!   bump_crate.rs tracey
//!   bump_crate.rs --all

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

struct CrateConfig {
    name: &'static str,
    version_var: &'static str,
}

const CRATES: &[CrateConfig] = &[
    CrateConfig { name: "codestyle", version_var: "codestyleVersion" },
    CrateConfig { name: "tracey", version_var: "traceyVersion" },
];

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

fn get_cargo_hash_from_build_error(repo_root: &Path) -> Option<String> {
    let output = Command::new("nix")
        .args(["build", ".#devShells.x86_64-linux.default"])
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

fn bump_crate(crate_cfg: &CrateConfig, repo_root: &Path) -> Result<bool, String> {
    println!("Checking {}...", crate_cfg.name);

    let latest = get_latest_version(crate_cfg.name)?;
    println!("  Latest version: {}", latest);

    let flake_path = repo_root.join("flake.nix");
    let rs_path = repo_root.join("rs/default.nix");

    let flake_content = fs::read_to_string(&flake_path)
        .map_err(|e| format!("Failed to read flake.nix: {}", e))?;
    let rs_content = fs::read_to_string(&rs_path)
        .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;

    let current = get_current_version(&flake_content, crate_cfg.version_var)
        .ok_or_else(|| format!("Could not find {} in flake.nix", crate_cfg.version_var))?;
    println!("  Current version: {}", current);

    if current == latest {
        println!("  Already up to date!");
        return Ok(false);
    }

    println!("  Updating {} -> {}...", current, latest);

    // Get new source hash
    println!("  Fetching source hash...");
    let src_hash = get_src_hash(crate_cfg.name, &latest)?;
    println!("  Source hash: {}", src_hash);

    // Update versions
    let flake_content = update_version(&flake_content, crate_cfg.version_var, &latest);
    let rs_content = update_version(&rs_content, crate_cfg.version_var, &latest);

    // Update source hash
    let rs_content = update_src_hash(&rs_content, crate_cfg.name, &src_hash);

    // Write updates
    fs::write(&flake_path, &flake_content)
        .map_err(|e| format!("Failed to write flake.nix: {}", e))?;
    fs::write(&rs_path, &rs_content)
        .map_err(|e| format!("Failed to write rs/default.nix: {}", e))?;

    // Try to build to get cargoHash
    println!("  Building to determine cargoHash (will fail once)...");
    if let Some(cargo_hash) = get_cargo_hash_from_build_error(repo_root) {
        println!("  New cargoHash: {}", cargo_hash);
        let rs_content = fs::read_to_string(&rs_path)
            .map_err(|e| format!("Failed to read rs/default.nix: {}", e))?;
        let rs_content = update_cargo_hash(&rs_content, crate_cfg.name, &cargo_hash);
        fs::write(&rs_path, rs_content)
            .map_err(|e| format!("Failed to write rs/default.nix: {}", e))?;
    }

    // Verify build
    println!("  Verifying build...");
    let status = Command::new("nix")
        .args(["build", ".#devShells.x86_64-linux.default"])
        .current_dir(repo_root)
        .status()
        .map_err(|e| format!("Failed to run nix build: {}", e))?;

    if status.success() {
        println!("  SUCCESS: {} updated to {}", crate_cfg.name, latest);
        Ok(true)
    } else {
        Err(format!("Build failed after update, may need manual intervention"))
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <crate-name> | --all", args[0]);
        eprintln!("Available crates: {}", CRATES.iter().map(|c| c.name).collect::<Vec<_>>().join(", "));
        return ExitCode::from(1);
    }

    // Find repo root (directory containing flake.nix)
    let mut repo_root = env::current_dir().expect("Failed to get current directory");
    while !repo_root.join("flake.nix").exists() {
        if !repo_root.pop() {
            eprintln!("ERROR: Could not find flake.nix in any parent directory");
            return ExitCode::from(1);
        }
    }

    let target = &args[1];
    let crates_to_bump: Vec<&CrateConfig> = if target == "--all" {
        CRATES.iter().collect()
    } else {
        match CRATES.iter().find(|c| c.name == target) {
            Some(c) => vec![c],
            None => {
                eprintln!("ERROR: Unknown crate '{}'. Available: {}", target,
                    CRATES.iter().map(|c| c.name).collect::<Vec<_>>().join(", "));
                return ExitCode::from(1);
            }
        }
    };

    let mut any_updated = false;
    let mut any_failed = false;

    for crate_cfg in crates_to_bump {
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
