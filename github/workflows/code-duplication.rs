#!/usr/bin/env -S cargo +nightly -Zscript -q
---cargo
[package]
edition = "2024"

[dependencies]
---

use std::io::{BufRead, BufReader};
use std::process::{Command, ExitCode, Stdio};

struct FileBlock {
    header: String,
    issues: Vec<Issue>,
}

struct Issue {
    lines: Vec<String>,
    is_duplication: bool,
}

fn main() -> ExitCode {
    let mut cmd = Command::new("qlty")
        .args(["smells", "--all"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("Failed to run qlty smells --all");

    let stdout = cmd.stdout.take().expect("Failed to capture stdout");
    let reader = BufReader::new(stdout);

    let mut files: Vec<FileBlock> = Vec::new();
    let mut current_file: Option<FileBlock> = None;
    let mut current_issue: Option<Issue> = None;
    let mut found_duplication = false;

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => continue,
        };

        if !line.is_empty() && !line.starts_with(' ') && !line.starts_with('\t') {
            if let (Some(file), Some(issue)) = (&mut current_file, current_issue.take()) {
                file.issues.push(issue);
            }
            if let Some(file) = current_file.take() {
                files.push(file);
            }
            current_file = Some(FileBlock {
                header: line,
                issues: Vec::new(),
            });
            continue;
        }

        let is_issue_header = line.starts_with("    ")
            && !line.starts_with("        ")
            && line.len() > 4
            && !line.chars().nth(4).unwrap_or(' ').is_whitespace();

        if is_issue_header {
            if let (Some(file), Some(issue)) = (&mut current_file, current_issue.take()) {
                file.issues.push(issue);
            }
            let is_dup = line.contains("similar code");
            if is_dup {
                found_duplication = true;
            }
            current_issue = Some(Issue {
                is_duplication: is_dup,
                lines: vec![line],
            });
            continue;
        }

        if let Some(issue) = &mut current_issue {
            issue.lines.push(line);
        }
    }

    if let (Some(file), Some(issue)) = (&mut current_file, current_issue.take()) {
        file.issues.push(issue);
    }
    if let Some(file) = current_file.take() {
        files.push(file);
    }

    for file in files {
        let dup_issues: Vec<_> = file.issues.into_iter().filter(|i| i.is_duplication).collect();
        if !dup_issues.is_empty() {
            println!("{}", file.header);
            for issue in dup_issues {
                for line in issue.lines {
                    println!("{}", line);
                }
                println!();
            }
        }
    }

    let _ = cmd.wait();
    if found_duplication {
        ExitCode::from(1)
    } else {
        ExitCode::from(0)
    }
}
