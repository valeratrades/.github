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
#! nix --command sh -c ``cargo -Zscript "$0" "$@"``
---

use std::{
    env,
    fs::{self, OpenOptions},
    io::{self, BufRead, BufReader, Write},
};

fn append_custom_code(file_path: &str) -> io::Result<()> {
    let custom_code = r#"script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$script_dir"/custom.sh"#;

    let file = fs::File::open(file_path)?;
    let reader = BufReader::new(file);
    let lines: Vec<String> = reader.lines().collect::<Result<_, _>>()?;

    if lines.len() > 1 && lines[lines.len() - 2].trim().is_empty() {
        let file = OpenOptions::new()
            .write(true)
            .append(false)
            .open(file_path)?;
        file.set_len(0)?;
        let mut writer = io::BufWriter::new(file);

        for line in &lines[..lines.len() - 1] {
            writeln!(writer, "{}", line)?;
        }

        writeln!(writer, "{}", custom_code)?;
        writeln!(writer, "{}", lines.last().unwrap())?;
    }

    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <file_path>", args[0]);
        std::process::exit(1);
    }

    let file_path = &args[1];
    if let Err(err) = append_custom_code(file_path) {
        eprintln!("Error: {}", err);
        std::process::exit(1);
    }
}
