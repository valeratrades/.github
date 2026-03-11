#!/usr/bin/env -S cargo -Zscript -q

---cargo
[package]
edition = "2024"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
---

//! Converts an .excalidraw file to a mermaid code block.
//!
//! Usage: ex-to-md <path.excalidraw>
//!
//! In standalone mode (no EX_INLINE_* env), writes to <path>.md.
//! In inline mode (EX_INLINE_FPATH + EX_INLINE_NUM set), replaces the Nth
//! mermaid block in the target file.

use std::{collections::HashSet, env, fs, path::PathBuf, process::ExitCode};

use serde::Deserialize;

#[derive(Deserialize)]
struct Excalidraw {
	elements: Vec<Element>,
}

#[derive(Deserialize)]
#[serde(tag = "type")]
enum Element {
	#[serde(rename = "rectangle")]
	Rectangle(Rect),
	#[serde(rename = "frame")]
	Frame(Rect),
	#[serde(rename = "text")]
	Text(TextEl),
	#[serde(rename = "arrow")]
	Arrow(ArrowEl),
	#[serde(other)]
	Other,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Rect {
	id: String,
	x: f64,
	y: f64,
	width: f64,
	height: f64,
	#[serde(default)]
	is_deleted: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TextEl {
	id: String,
	x: f64,
	y: f64,
	width: f64,
	height: f64,
	text: String,
	#[serde(default)]
	is_deleted: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ArrowEl {
	start_binding: Option<Binding>,
	end_binding: Option<Binding>,
	#[serde(default)]
	bound_elements: Vec<BoundRef>,
	#[serde(default)]
	is_deleted: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Binding {
	element_id: String,
}

#[derive(Deserialize)]
struct BoundRef {
	id: String,
}

struct Node {
	id: String,
	label: String,
	rect_id: Option<String>,
}

struct Edge {
	from: String,
	to: String,
	label: String,
}

fn contains(rect: &Rect, text: &TextEl) -> bool {
	const PAD: f64 = 80.0;
	text.x >= rect.x - PAD && text.y >= rect.y - PAD && text.x + text.width <= rect.x + rect.width + PAD && text.y + text.height <= rect.y + rect.height + PAD
}

fn make_id(s: &str) -> String {
	let s = s.trim_start_matches(|c| c == '#' || c == ' ');
	let mut out = String::new();
	for c in s.chars() {
		if c.is_ascii_alphanumeric() {
			out.push(c);
		} else {
			out.push('_');
		}
	}
	out.split('_').filter(|s| !s.is_empty()).collect::<Vec<_>>().join("_")
}

fn escape_mermaid(s: &str) -> String {
	s.replace('"', "#quot;").replace('<', "#lt;").replace('>', "#gt;").replace('\n', "<br/>")
}

fn is_heading(s: &str) -> bool {
	s.starts_with("# ") || s.starts_with("## ") || s.starts_with("### ")
}

fn strip_heading(s: &str) -> &str {
	s.trim_start_matches('#').trim_start()
}

/// Replace the `num`-th (1-indexed) ```mermaid``` block in `content` with `replacement`.
fn replace_nth_mermaid_block(content: &str, num: usize, replacement: &str) -> Option<String> {
	let mut result = String::with_capacity(content.len());
	let mut rest = content;
	let mut found = 0usize;

	while let Some(start) = rest.find("```mermaid\n") {
		let after_open = start + "```mermaid\n".len();
		let Some(end_rel) = rest[after_open..].find("```") else {
			break;
		};
		let end = after_open + end_rel + "```".len();
		found += 1;

		if found == num {
			result.push_str(&rest[..start]);
			result.push_str(replacement);
			result.push_str(&rest[end..]);
			return Some(result);
		}

		result.push_str(&rest[..end]);
		rest = &rest[end..];
	}

	None
}

fn main() -> ExitCode {
	let in_path = PathBuf::from(env::args().nth(1).unwrap_or_else(|| {
		eprintln!("Usage: ex-to-md <path.excalidraw>");
		std::process::exit(1);
	}));

	let content = fs::read_to_string(&in_path).unwrap_or_else(|e| {
		eprintln!("Failed to read {}: {e}", in_path.display());
		std::process::exit(1);
	});

	let data: Excalidraw = serde_json::from_str(&content).unwrap_or_else(|e| {
		eprintln!("Failed to parse {}: {e}", in_path.display());
		std::process::exit(1);
	});

	let mut rects = Vec::new();
	let mut texts = Vec::new();
	let mut arrows = Vec::new();

	for el in &data.elements {
		match el {
			Element::Rectangle(r) | Element::Frame(r) if !r.is_deleted => rects.push(r),
			Element::Text(t) if !t.is_deleted => texts.push(t),
			Element::Arrow(a) if !a.is_deleted => arrows.push(a),
			_ => {}
		}
	}

	let mut nodes: Vec<Node> = Vec::new();
	let mut assigned_text_ids: HashSet<&str> = HashSet::new();

	if !rects.is_empty() {
		for rect in &rects {
			let inside: Vec<&&TextEl> = texts.iter().filter(|t| contains(rect, t)).collect();
			let heading = inside.iter().find(|t| is_heading(&t.text));
			let body: Vec<&&TextEl> = inside.iter().filter(|t| !is_heading(&t.text)).copied().collect();
			for t in &inside {
				assigned_text_ids.insert(&t.id);
			}

			let raw_label = match heading {
				Some(h) => strip_heading(&h.text).to_string(),
				None => format!("node_{}", &rect.id[..rect.id.len().min(6)]),
			};
			let id = make_id(&raw_label);
			let desc: String = body.iter().map(|t| t.text.as_str()).collect::<Vec<_>>().join("\n");
			let label = if desc.is_empty() {
				escape_mermaid(&raw_label)
			} else {
				format!("{}<br/><br/>{}", raw_label, escape_mermaid(&desc))
			};
			nodes.push(Node {
				id,
				label,
				rect_id: Some(rect.id.clone()),
			});
		}

		for t in &texts {
			if !assigned_text_ids.contains(t.id.as_str()) {
				let first_line = t.text.lines().next().unwrap_or("");
				let id = make_id(first_line);
				if !id.is_empty() {
					nodes.push(Node {
						id,
						label: escape_mermaid(&t.text),
						rect_id: None,
					});
				}
			}
		}
	} else {
		let headings: Vec<&&TextEl> = texts.iter().filter(|t| is_heading(&t.text)).collect();
		let body_texts: Vec<&&TextEl> = texts.iter().filter(|t| !is_heading(&t.text)).collect();
		for h in &headings {
			let raw_label = strip_heading(&h.text).to_string();
			let id = make_id(&raw_label);
			let desc: String = body_texts.iter().filter(|b| (b.x - h.x).abs() < 300.0).map(|b| b.text.as_str()).collect::<Vec<_>>().join("\n");
			let label = if desc.is_empty() {
				escape_mermaid(&raw_label)
			} else {
				format!("{}<br/><br/>{}", raw_label, escape_mermaid(&desc))
			};
			nodes.push(Node { id, label, rect_id: None });
		}
	}

	nodes.sort_by(|a, b| {
		let xa = a.rect_id.as_ref().and_then(|rid| rects.iter().find(|r| r.id == *rid)).map(|r| r.x).unwrap_or(0.0);
		let xb = b.rect_id.as_ref().and_then(|rid| rects.iter().find(|r| r.id == *rid)).map(|r| r.x).unwrap_or(0.0);
		xa.partial_cmp(&xb).unwrap()
	});

	let mut edges: Vec<Edge> = Vec::new();
	for arrow in &arrows {
		let (Some(start), Some(end)) = (&arrow.start_binding, &arrow.end_binding) else {
			continue;
		};
		let Some(from) = nodes.iter().find(|n| n.rect_id.as_deref() == Some(&start.element_id)) else {
			continue;
		};
		let Some(to) = nodes.iter().find(|n| n.rect_id.as_deref() == Some(&end.element_id)) else {
			continue;
		};
		let edge_label = arrow
			.bound_elements
			.iter()
			.find_map(|b| texts.iter().find(|t| t.id == b.id).map(|t| escape_mermaid(&t.text)))
			.unwrap_or_default();
		edges.push(Edge {
			from: from.id.clone(),
			to: to.id.clone(),
			label: edge_label,
		});
	}

	let mut lines = vec!["```mermaid".to_string(), "flowchart LR".to_string()];
	for n in &nodes {
		lines.push(format!("  {}[\"{}\"]", n.id, n.label));
	}
	for e in &edges {
		if e.label.is_empty() {
			lines.push(format!("  {} --> {}", e.from, e.to));
		} else {
			lines.push(format!("  {} -->|\"{}\"| {}", e.from, e.label, e.to));
		}
	}
	lines.push("```".to_string());

	let mermaid_block = lines.join("\n") + "\n";

	let inline_fpath = env::var("EX_INLINE_FPATH").ok().filter(|s| !s.is_empty());
	let inline_num: usize = env::var("EX_INLINE_NUM").ok().and_then(|s| s.parse().ok()).unwrap_or(0);

	if let Some(fpath) = inline_fpath {
		let target = PathBuf::from(&fpath);
		let file_content = fs::read_to_string(&target).unwrap_or_else(|e| {
			eprintln!("Failed to read {}: {e}", target.display());
			std::process::exit(1);
		});

		match replace_nth_mermaid_block(&file_content, inline_num, &mermaid_block) {
			Some(new_content) => {
				fs::write(&target, &new_content).unwrap_or_else(|e| {
					eprintln!("Failed to write {}: {e}", target.display());
					std::process::exit(1);
				});
				println!("Updated mermaid block #{inline_num} in {}", target.display());
			}
			None => {
				eprintln!(
					"Mermaid block #{inline_num} not found in {}. Place a ```mermaid``` block there first.",
					target.display()
				);
				std::process::exit(1);
			}
		}
	} else {
		let out_path = in_path.with_extension("md");
		fs::write(&out_path, &mermaid_block).unwrap_or_else(|e| {
			eprintln!("Failed to write {}: {e}", out_path.display());
			std::process::exit(1);
		});
		println!("Written: {}", out_path.display());
	}

	ExitCode::SUCCESS
}
