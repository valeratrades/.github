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
toml_edit = "0.22"
---

//! Ensures [package.metadata.binstall] section exists in Cargo.toml
//! Usage: ensure_binstall_metadata.rs [Cargo.toml path]

use std::{env, fs, path::Path};
use toml_edit::{DocumentMut, Item, Table};

fn ensure_binstall_metadata(cargo_toml_path: &Path) -> Result<bool, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(cargo_toml_path)?;
    let mut doc = content.parse::<DocumentMut>()?;

    // Check if [package.metadata.binstall] already exists
    if let Some(package) = doc.get("package") {
        if let Some(metadata) = package.get("metadata") {
            if metadata.get("binstall").is_some() {
                return Ok(false); // Already exists
            }
        }
    }

    // Verify repository URL exists in [package] (required for binstall)
    let _repo = doc
        .get("package")
        .and_then(|p| p.get("repository"))
        .and_then(|r| r.as_str())
        .ok_or("No repository field in [package] - required for binstall")?;

    // Ensure [package.metadata] exists
    let package = doc["package"].as_table_mut().ok_or("No [package] table")?;
    if !package.contains_key("metadata") {
        package.insert("metadata", Item::Table(Table::new()));
    }
    let metadata = package["metadata"]
        .as_table_mut()
        .ok_or("metadata is not a table")?;

    // Create binstall table
    let mut binstall = Table::new();

    // Use { } template syntax for binstall
    binstall.insert(
        "pkg-url",
        toml_edit::value(format!(
            "{{ repo }}/releases/download/v{{ version }}/{{ name }}-{{ target }}.tar.gz"
        )),
    );
    binstall.insert("bin-dir", toml_edit::value("{ bin }{ binary-ext }"));
    binstall.insert("pkg-fmt", toml_edit::value("tgz"));

    metadata.insert("binstall", Item::Table(binstall));

    fs::write(cargo_toml_path, doc.to_string())?;
    Ok(true)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let cargo_toml_path = if args.len() > 1 {
        Path::new(&args[1]).to_path_buf()
    } else {
        Path::new("Cargo.toml").to_path_buf()
    };

    if !cargo_toml_path.exists() {
        eprintln!("Cargo.toml not found at {:?}", cargo_toml_path);
        std::process::exit(1);
    }

    match ensure_binstall_metadata(&cargo_toml_path) {
        Ok(true) => println!("Added [package.metadata.binstall] to {:?}", cargo_toml_path),
        Ok(false) => {} // Already exists, silent
        Err(e) => {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
    }
}
