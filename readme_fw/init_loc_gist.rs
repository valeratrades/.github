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

use clap::Parser;
use serde::Deserialize;
use std::io::{self, Write};
use std::process::Command;

#[derive(Parser, Debug)]
#[command(name = "init-loc-gist")]
#[command(about = "Initialize LOC badge file in GitHub gist")]
struct Args {
    /// Project name (used as {pname}-loc.json)
    #[arg(long)]
    pname: String,

    /// Gist ID to update
    #[arg(long)]
    gist_id: String,
}

#[derive(Deserialize)]
struct GistFile {
    raw_url: String,
}

#[derive(Deserialize)]
struct Gist {
    files: std::collections::HashMap<String, GistFile>,
}

fn get_loc() -> u64 {
    let output = Command::new("tokei")
        .args(["--output", "json"])
        .output()
        .expect("Failed to run tokei. Is it installed?");

    if !output.status.success() {
        panic!(
            "tokei failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let json: serde_json::Value = serde_json::from_slice(&output.stdout)
        .expect("Failed to parse tokei output");

    json["Total"]["code"]
        .as_u64()
        .expect("Failed to get LOC from tokei output")
}

fn gist_file_exists(gist_id: &str, filename: &str) -> Result<bool, String> {
    let output = Command::new("gh")
        .args(["api", &format!("gists/{}", gist_id)])
        .output()
        .map_err(|e| format!("Failed to run gh: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.contains("Not Found") {
            return Err(format!("Gist {} not found", gist_id));
        }
        return Err(format!("gh api failed: {}", stderr));
    }

    let gist: Gist = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse gist: {}", e))?;

    Ok(gist.files.contains_key(filename))
}

fn create_gist_file(gist_id: &str, filename: &str, loc: u64) -> Result<(), String> {
    let json_content = format!(
        r#"{{"schemaVersion": 1, "label": "LoC", "message": "{}", "color": "lightblue"}}"#,
        loc
    );

    let jq_expr = format!(
        r#".files."{}" = {{"content": "{}"}}"#,
        filename,
        json_content.replace('"', r#"\""#)
    );

    let output = Command::new("gh")
        .args([
            "api",
            "--method",
            "PATCH",
            &format!("gists/{}", gist_id),
            "--input",
            "-",
        ])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn gh: {}", e))?;

    let body = format!(r#"{{"files": {{"{filename}": {{"content": "{json_content}"}}}}}}"#);

    let mut stdin = output.stdin.as_ref().ok_or("Failed to get stdin")?;
    stdin
        .write_all(body.as_bytes())
        .map_err(|e| format!("Failed to write to stdin: {}", e))?;
    drop(stdin);

    let output = output
        .wait_with_output()
        .map_err(|e| format!("Failed to wait for gh: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "gh api PATCH failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(())
}

fn main() {
    let args = Args::parse();
    let filename = format!("{}-loc.json", args.pname);

    match gist_file_exists(&args.gist_id, &filename) {
        Ok(true) => {
            println!("File {} already exists in gist {}", filename, args.gist_id);
        }
        Ok(false) => {
            println!("File {} does not exist, creating...", filename);
            let loc = get_loc();
            println!("Counted {} lines of code", loc);

            match create_gist_file(&args.gist_id, &filename, loc) {
                Ok(()) => println!("Created {} in gist {}", filename, args.gist_id),
                Err(e) => {
                    eprintln!("ERROR: {}", e);
                    std::process::exit(1);
                }
            }
        }
        Err(e) => {
            eprintln!("ERROR: {}", e);
            std::process::exit(1);
        }
    }
}
