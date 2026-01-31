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
dirs = "6"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
---

use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::{self, BufRead, IsTerminal, Write};
use std::path::PathBuf;
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
        /// Labels in format "name:color[:description]" (color without #), can be repeated
        #[arg(short, long, value_parser = parse_label)]
        label: Vec<LabelSpec>,

        /// Check for duplicate or too-similar colors
        #[arg(long)]
        check_duplicate_colors: bool,
    },
}

#[derive(Debug, Clone, Hash)]
struct LabelSpec {
    name: String,
    color: String,
    description: Option<String>,
}

fn parse_label(s: &str) -> Result<LabelSpec, String> {
    let parts: Vec<&str> = s.splitn(3, ':').collect();
    if parts.len() < 2 {
        return Err(format!("Invalid label format '{}', expected 'name:color[:description]'", s));
    }
    let name = parts[0].to_string();
    let color = parts[1].trim_start_matches('#').to_string();
    if color.len() != 6 || !color.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("Invalid color '{}', expected 6-digit hex", parts[1]));
    }
    let description = parts.get(2).filter(|d| !d.is_empty()).map(|d| d.to_string());
    Ok(LabelSpec { name, color, description })
}

/// Compute a stable hash of the label configuration
fn compute_labels_hash(labels: &[LabelSpec]) -> u64 {
    let mut sorted: Vec<_> = labels.iter().collect();
    sorted.sort_by(|a, b| a.name.cmp(&b.name));
    let mut hasher = DefaultHasher::new();
    for label in sorted {
        label.hash(&mut hasher);
    }
    hasher.finish()
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct SyncState {
    /// Map from absolute repo path to hash of synced labels
    synced: HashMap<String, u64>,
}

fn state_file_path() -> PathBuf {
    let state_dir = dirs::state_dir()
        .expect("XDG_STATE_HOME not available")
        .join("git_ops");
    state_dir.join("sync_labels.json")
}

fn load_sync_state() -> SyncState {
    let path = state_file_path();
    match fs::read_to_string(&path) {
        Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
        Err(_) => SyncState::default(),
    }
}

fn save_sync_state(state: &SyncState) {
    let path = state_file_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("failed to create state directory");
    }
    let content = serde_json::to_string_pretty(state).expect("failed to serialize state");
    fs::write(&path, content).expect("failed to write state file");
}

fn get_repo_root() -> Option<String> {
    let output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        None
    }
}

#[derive(Debug, Deserialize)]
struct GhLabel {
    name: String,
    color: String,
    description: Option<String>,
}

fn run_gh(args: &[&str]) -> io::Result<std::process::Output> {
    Command::new("gh").args(args).output()
}

fn run_gh_success(args: &[&str]) -> bool {
    run_gh(args).map(|o| o.status.success()).unwrap_or(false)
}

fn get_remote_labels() -> Result<Vec<GhLabel>, String> {
    let output = run_gh(&["label", "list", "--json", "name,color,description", "--limit", "1000"])
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

fn create_label(name: &str, color: &str, description: Option<&str>) -> bool {
    match description {
        Some(desc) => run_gh_success(&["label", "create", name, "--color", color, "--description", desc, "--force"]),
        None => run_gh_success(&["label", "create", name, "--color", color, "--force"]),
    }
}

fn update_label(name: &str, color: &str, description: Option<&str>) -> bool {
    match description {
        Some(desc) => run_gh_success(&["label", "edit", name, "--color", color, "--description", desc]),
        None => run_gh_success(&["label", "edit", name, "--color", color]),
    }
}

fn delete_label(name: &str) -> bool {
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

fn hex_to_rgb(hex: &str) -> (u8, u8, u8) {
    let hex = hex.trim_start_matches('#');
    let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(0);
    let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(0);
    let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(0);
    (r, g, b)
}

fn rgb_to_hsl(r: u8, g: u8, b: u8) -> (f64, f64, f64) {
    let r = r as f64 / 255.0;
    let g = g as f64 / 255.0;
    let b = b as f64 / 255.0;

    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let l = (max + min) / 2.0;

    if (max - min).abs() < f64::EPSILON {
        return (0.0, 0.0, l * 100.0);
    }

    let d = max - min;
    let s = if l > 0.5 {
        d / (2.0 - max - min)
    } else {
        d / (max + min)
    };

    let h = if (max - r).abs() < f64::EPSILON {
        let mut h = (g - b) / d;
        if g < b {
            h += 6.0;
        }
        h
    } else if (max - g).abs() < f64::EPSILON {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };

    (h * 60.0, s * 100.0, l * 100.0)
}

fn check_duplicate_colors(labels: &[LabelSpec]) -> Result<(), String> {
    // Check exact duplicates
    let mut color_to_name: HashMap<String, &str> = HashMap::new();
    for label in labels {
        let color_lower = label.color.to_lowercase();
        if let Some(existing) = color_to_name.get(&color_lower) {
            return Err(format!(
                "Duplicate color #{}: '{}' and '{}'",
                label.color, existing, label.name
            ));
        }
        color_to_name.insert(color_lower, &label.name);
    }

    // Convert to HSL and sort by hue
    let mut hsl_labels: Vec<(&str, &str, f64, f64, f64)> = labels
        .iter()
        .map(|label| {
            let (r, g, b) = hex_to_rgb(&label.color);
            let (h, s, l) = rgb_to_hsl(r, g, b);
            (label.name.as_str(), label.color.as_str(), h, s, l)
        })
        .collect();

    hsl_labels.sort_by(|a, b| a.2.partial_cmp(&b.2).unwrap());

    // Check adjacent colors (including wrap-around from last to first)
    for i in 0..hsl_labels.len() {
        let (name1, color1, h1, s1, l1) = hsl_labels[i];
        let (name2, color2, h2, s2, l2) = hsl_labels[(i + 1) % hsl_labels.len()];

        // Calculate hue difference (accounting for wrap-around at 360)
        let h_diff = if i + 1 == hsl_labels.len() {
            // Wrap-around case
            (360.0 - h1 + h2).min(h1 - h2 + 360.0).abs()
        } else {
            (h2 - h1).abs()
        };

        if h_diff < 16.0 {
            let s_diff = (s2 - s1).abs();
            let l_diff = (l2 - l1).abs();
            let total_diff = h_diff + s_diff + l_diff;

            if total_diff < 32.0 {
                return Err(format!(
                    "Colors too similar (diff={:.1}): '{}' #{} and '{}' #{}",
                    total_diff, name1, color1, name2, color2
                ));
            }
        }
    }

    Ok(())
}

fn sync_labels(local_labels: Vec<LabelSpec>, check_colors: bool) {
    if check_colors {
        if let Err(e) = check_duplicate_colors(&local_labels) {
            eprintln!("ERROR: {}", e);
            std::process::exit(1);
        }
        println!("Color check passed.");
    }

    // Check if we've already synced this exact label configuration for this repo
    let current_hash = compute_labels_hash(&local_labels);
    let repo_root = get_repo_root().expect("not in a git repository");
    let mut state = load_sync_state();

    if state.synced.get(&repo_root) == Some(&current_hash) {
        // Already synced this configuration, nothing to do
        return;
    }

    let remote_labels = match get_remote_labels() {
        Ok(labels) => labels,
        Err(e) => {
            eprintln!("ERROR: {}", e);
            std::process::exit(1);
        }
    };

    let local_map: HashMap<String, (String, Option<String>)> = local_labels
        .into_iter()
        .map(|l| (l.name, (l.color, l.description)))
        .collect();
    let remote_map: HashMap<String, (String, Option<String>)> = remote_labels
        .into_iter()
        .map(|l| (l.name, (l.color, l.description)))
        .collect();

    let mut created = 0;
    let mut updated = 0;
    let mut deleted = 0;

    // Create or update labels
    for (name, (color, description)) in &local_map {
        match remote_map.get(name) {
            None => {
                if create_label(name, color, description.as_deref()) {
                    created += 1;
                } else {
                    eprintln!("  Failed to create label '{}'", name);
                }
            }
            Some((remote_color, remote_desc)) => {
                let color_differs = remote_color.to_lowercase() != color.to_lowercase();
                let desc_differs = remote_desc != description;
                if color_differs || desc_differs {
                    if update_label(name, color, description.as_deref()) {
                        updated += 1;
                    } else {
                        eprintln!("  Failed to update label '{}'", name);
                    }
                }
            }
        }
    }

    // Find labels to delete (only prompt in interactive mode)
    let to_delete: Vec<&String> = remote_map
        .keys()
        .filter(|name| !local_map.contains_key(*name))
        .collect();

    if !to_delete.is_empty() && io::stdin().is_terminal() {
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

    // Update cache with current hash
    state.synced.insert(repo_root, current_hash);
    save_sync_state(&state);

    // Only print summary if there were actual changes
    if created > 0 || updated > 0 || deleted > 0 {
        println!(
            "Labels synced: {} created, {} updated, {} deleted",
            created, updated, deleted
        );
    }
}

fn main() {
    let args = Args::parse();

    match args.command {
        Commands::SyncLabels { label, check_duplicate_colors } => {
            if label.is_empty() {
                eprintln!("ERROR: No labels specified. Use -l 'name:color' to specify labels.");
                std::process::exit(1);
            }
            sync_labels(label, check_duplicate_colors);
        }
    }
}
