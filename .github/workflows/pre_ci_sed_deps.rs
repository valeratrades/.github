#!/usr/bin/env -S cargo +nightly -Zscript -q

use std::{
	fs,
	io::{self, BufRead, BufReader, Write},
	path::{Path, PathBuf},
};

fn process_file(path: &Path) -> io::Result<bool> {
	let file = fs::File::open(path)?;
	let reader = BufReader::new(file);
	let mut lines: Vec<String> = Vec::new();
	let mut in_dependencies = false;
	let mut modified = false;

	for line in reader.lines() {
		let mut line = line?;

		// Only want to modify thing in the dependencies section
		if line.trim().starts_with('[') && line.trim().ends_with("dependencies]") {
			in_dependencies = true;
			lines.push(line);
			continue;
		}
		if in_dependencies && line.trim().starts_with('[') {
			in_dependencies = false;
		}

		if in_dependencies && line.contains("path =") {
			let comment = line.split('#').nth(1).unwrap_or("");
			if comment.contains("ga: sub path") || comment.contains("ga: substitute path") {
				// Replace path with version = "*"
				line = line.replace(&line[..line.find('#').unwrap_or(line.len())], &line[..line.find("path =").unwrap()]) + "version = \"*\" #" + comment;
				modified = true;
			} else if comment.contains("ga: rm path") || comment.contains("ga: remove path") {
				// Remove path attribute while preserving others.
				// Normally takes responsibility for comma _after_. If attribute is last, take responsibility for comma _before_.
				let path_eq_idx = line.find("path =").unwrap();
				match line[path_eq_idx..].find(',') {
					Some(path_end) => {
						line = format!("{}{}", &line[..path_eq_idx], &line[path_eq_idx + path_end + 1..]);
					}
					None => {
						let start_comma = line[..path_eq_idx].rfind(',').unwrap();
						let path_end = line[path_eq_idx..].find('}').unwrap();
						line = format!("{}{}", &line[..start_comma], &line[path_eq_idx + path_end..]);
					}
				}

				modified = true;
			}
		}

		if line.contains("#ga: comment") || line.contains("#ga: comment out") {
			line = format!("# {}", line);
			modified = true;
		}

		lines.push(line);
	}

	if modified {
		let temp_path = path.with_extension("toml.tmp");
		{
			let mut temp_file = fs::File::create(&temp_path)?;
			for line in &lines {
				writeln!(temp_file, "{}", line)?;
			}
		}
		fs::rename(temp_path, path)?;
	}

	Ok(modified)
}

fn visit_dirs(root_dir: &Path) -> io::Result<Vec<PathBuf>> {
	let mut cargo_files = Vec::new();
	if root_dir.is_dir() {
		for entry in fs::read_dir(root_dir)? {
			let entry = entry?;
			let path = entry.path();
			if path.is_dir() {
				if !path.to_string_lossy().contains(".git") {
					cargo_files.extend(visit_dirs(&path)?);
				}
			} else if path.file_name().map(|s| s == "Cargo.toml").unwrap_or(false) {
				cargo_files.push(path);
			}
		}
	}
	Ok(cargo_files)
}

fn main() -> io::Result<()> {
	let path = match std::env::args().nth(1) {
		Some(path) => Path::new(&path),
		None => {
			eprintln!("Usage: {} <file_path>", std::env::args().next().unwrap());
			std::process::exit(1);
		}
	};

	let mut modified_any = false;

	for cargo_path in dbg!(visit_dirs(path)?) {
		if process_file(&cargo_path)? {
			println!("Modified: {}", cargo_path.display());
			modified_any = true;
		}
	}

	if !modified_any {
		println!("No Cargo.toml files were modified");
	}

	Ok(())
}
