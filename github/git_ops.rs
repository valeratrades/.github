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
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
---

use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::process::Command;

#[derive(Parser, Debug)]
#[command(name = "vgit")]
#[command(about = "GitHub repository management utilities")]
struct Args {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Sync repository labels with local configuration
    SyncLabels {
        /// Labels in format "name:color" (color without #), can be repeated
        #[arg(short, long, value_parser = parse_label)]
        label: Vec<(String, String)>,
    },
}

fn parse_label(s: &str) -> Result<(String, String), String> {
    let parts: Vec<&str> = s.splitn(2, ':').collect();
    if parts.len() != 2 {
        return Err(format!("Invalid label format '{}', expected 'name:color'", s));
    }
    let name = parts[0].to_string();
    let color = parts[1].trim_start_matches('#').to_string();
    if color.len() != 6 || !color.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("Invalid color '{}', expected 6-digit hex", parts[1]));
    }
    Ok((name, color))
}

#[derive(Debug, Deserialize)]
struct GhLabel {
    name: String,
    color: String,
}

fn run_gh(args: &[&str]) -> io::Result<std::process::Output> {
    Command::new("gh").args(args).output()
}

fn run_gh_success(args: &[&str]) -> bool {
    run_gh(args).map(|o| o.status.success()).unwrap_or(false)
}

fn get_remote_labels() -> Result<Vec<GhLabel>, String> {
    let output = run_gh(&["label", "list", "--json", "name,color", "--limit", "1000"])
        .map_err(|e| format!("Failed to run gh: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "gh label list failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let labels: Vec<GhLabel> = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse labels: {}", e))?;

    Ok(labels)
}

fn create_label(name: &str, color: &str) -> bool {
    println!("  Creating label '{}' with color #{}", name, color);
    run_gh_success(&["label", "create", name, "--color", color, "--force"])
}

fn update_label(name: &str, color: &str) -> bool {
    println!("  Updating label '{}' to color #{}", name, color);
    run_gh_success(&["label", "edit", name, "--color", color])
}

fn delete_label(name: &str) -> bool {
    println!("  Deleting label '{}'", name);
    run_gh_success(&["label", "delete", name, "--yes"])
}

fn prompt_yes_no(question: &str) -> bool {
    print!("{} [y/N]: ", question);
    io::stdout().flush().unwrap();

    let stdin = io::stdin();
    let mut line = String::new();
    if stdin.lock().read_line(&mut line).is_err() {
        return false;
    }

    matches!(line.trim().to_lowercase().as_str(), "y" | "yes")
}

fn check_duplicate_colors(labels: &[(String, String)]) -> Result<(), String> {
    let mut color_to_name: HashMap<String, &str> = HashMap::new();
    for (name, color) in labels {
        let color_lower = color.to_lowercase();
        if let Some(existing) = color_to_name.get(&color_lower) {
            return Err(format!(
                "Duplicate color #{}: '{}' and '{}'",
                color, existing, name
            ));
        }
        color_to_name.insert(color_lower, name);
    }
    Ok(())
}

fn sync_labels(local_labels: Vec<(String, String)>) {
    // Check for duplicate colors
    if let Err(e) = check_duplicate_colors(&local_labels) {
        eprintln!("ERROR: {}", e);
        std::process::exit(1);
    }

    println!("Fetching remote labels...");

    let remote_labels = match get_remote_labels() {
        Ok(labels) => labels,
        Err(e) => {
            eprintln!("ERROR: {}", e);
            std::process::exit(1);
        }
    };

    let local_map: HashMap<String, String> = local_labels.into_iter().collect();
    let remote_map: HashMap<String, String> = remote_labels
        .into_iter()
        .map(|l| (l.name, l.color))
        .collect();

    let mut created = 0;
    let mut updated = 0;
    let mut deleted = 0;

    // Create or update labels
    for (name, color) in &local_map {
        match remote_map.get(name) {
            None => {
                if create_label(name, color) {
                    created += 1;
                } else {
                    eprintln!("  Failed to create label '{}'", name);
                }
            }
            Some(remote_color) if remote_color.to_lowercase() != color.to_lowercase() => {
                if update_label(name, color) {
                    updated += 1;
                } else {
                    eprintln!("  Failed to update label '{}'", name);
                }
            }
            _ => {}
        }
    }

    // Find labels to delete
    let to_delete: Vec<&String> = remote_map
        .keys()
        .filter(|name| !local_map.contains_key(*name))
        .collect();

    if !to_delete.is_empty() {
        println!("\nRemote labels not in local config:");
        for name in &to_delete {
            println!("  - {}", name);
        }

        if prompt_yes_no("\nDelete these labels?") {
            for name in to_delete {
                if delete_label(name) {
                    deleted += 1;
                } else {
                    eprintln!("  Failed to delete label '{}'", name);
                }
            }
        }
    }

    println!(
        "\nSync complete: {} created, {} updated, {} deleted",
        created, updated, deleted
    );
}

fn main() {
    let args = Args::parse();

    match args.command {
        Commands::SyncLabels { label } => {
            if label.is_empty() {
                eprintln!("ERROR: No labels specified. Use -l 'name:color' to specify labels.");
                std::process::exit(1);
            }
            sync_labels(label);
        }
    }
}
