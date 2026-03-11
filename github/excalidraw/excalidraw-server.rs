#!/usr/bin/env -S cargo -Zscript -q

---cargo
[package]
edition = "2024"

[dependencies]
serde_json = "1"
---

//! Excalidraw editor server.
//!
//! Usage: excalidraw-server <path.excalidraw>
//! Requires EX_HTML_PATH env var pointing to excalidraw-app.html.

use std::{
	env,
	fs,
	io::{BufRead, BufReader, Write},
	net::TcpListener,
	path::PathBuf,
	process::ExitCode,
	sync::{
		Arc,
		atomic::{AtomicU64, Ordering},
	},
	time::{SystemTime, UNIX_EPOCH},
};

const PORT: u16 = 3741;
const HEARTBEAT_TIMEOUT_MS: u64 = 8000;

fn now_ms() -> u64 {
	SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64
}

fn main() -> ExitCode {
	let file_path = PathBuf::from(env::args().nth(1).unwrap_or_else(|| {
		eprintln!("Usage: excalidraw-server <path.excalidraw>");
		std::process::exit(1);
	}));

	let name = file_path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| "excalidraw".to_string());

	let html_path = env::var("EX_HTML_PATH").unwrap_or_else(|_| {
		eprintln!("EX_HTML_PATH not set");
		std::process::exit(1);
	});

	if !file_path.exists() {
		eprintln!("File not found: {}", file_path.display());
		return ExitCode::FAILURE;
	}

	let html_template = fs::read_to_string(&html_path).unwrap_or_else(|e| {
		eprintln!("Failed to read {html_path}: {e}");
		std::process::exit(1);
	});
	let html = html_template.replace("arch -- Excalidraw", &format!("{name} -- Excalidraw"));

	let last_heartbeat = Arc::new(AtomicU64::new(now_ms()));

	let listener = TcpListener::bind(format!("127.0.0.1:{PORT}")).unwrap_or_else(|e| {
		eprintln!("Failed to bind to port {PORT}: {e}");
		std::process::exit(1);
	});

	eprintln!("Excalidraw ready: http://localhost:{PORT}");
	eprintln!("Editing: {}", file_path.display());
	eprintln!("Alt+W to save. Ctrl+C to stop.");

	let hb = Arc::clone(&last_heartbeat);
	std::thread::spawn(move || loop {
		std::thread::sleep(std::time::Duration::from_secs(3));
		if now_ms() - hb.load(Ordering::Relaxed) > HEARTBEAT_TIMEOUT_MS {
			eprintln!("Tab closed, shutting down.");
			std::process::exit(0);
		}
	});

	for stream in listener.incoming() {
		let mut stream = match stream {
			Ok(s) => s,
			Err(_) => continue,
		};

		let mut reader = BufReader::new(stream.try_clone().unwrap());
		let mut request_line = String::new();
		if reader.read_line(&mut request_line).is_err() {
			continue;
		}
		let parts: Vec<&str> = request_line.trim().split(' ').collect();
		if parts.len() < 2 {
			continue;
		}
		let method = parts[0];
		let path = parts[1];

		let mut content_length: usize = 0;
		loop {
			let mut line = String::new();
			if reader.read_line(&mut line).is_err() || line.trim().is_empty() {
				break;
			}
			let lower = line.to_ascii_lowercase();
			if let Some(val) = lower.strip_prefix("content-length:") {
				content_length = val.trim().parse().unwrap_or(0);
			}
		}

		let cors = "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type";

		match (method, path) {
			("OPTIONS", _) => {
				let _ = write!(stream, "HTTP/1.1 204 No Content\r\n{cors}\r\n\r\n");
			}
			("GET", "/") => {
				let len = html.len();
				let _ = write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{html}");
			}
			("POST", "/api/heartbeat") => {
				last_heartbeat.store(now_ms(), Ordering::Relaxed);
				let _ = write!(stream, "HTTP/1.1 204 No Content\r\n{cors}\r\n\r\n");
			}
			("GET", "/api/load") => match fs::read_to_string(&file_path) {
				Ok(content) => {
					let len = content.len();
					let _ = write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{content}");
				}
				Err(e) => {
					let body = format!("{{\"error\":\"{e}\"}}");
					let len = body.len();
					let _ = write!(stream, "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{body}");
				}
			},
			("POST", "/api/save") => {
				let mut body = vec![0u8; content_length];
				if std::io::Read::read_exact(&mut reader, &mut body).is_ok() {
					let body_str = String::from_utf8_lossy(&body);
					match serde_json::from_str::<serde_json::Value>(&body_str) {
						Ok(parsed) => {
							let pretty = serde_json::to_string_pretty(&parsed).unwrap();
							if let Err(e) = fs::write(&file_path, &pretty) {
								let err_body = format!("{{\"error\":\"{e}\"}}");
								let len = err_body.len();
								let _ = write!(stream, "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{err_body}");
							} else {
								let ok = r#"{"ok":true}"#;
								let len = ok.len();
								let _ = write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{ok}");
								eprint!("saved\n");
							}
						}
						Err(e) => {
							let err_body = format!("{{\"error\":\"{e}\"}}");
							let len = err_body.len();
							let _ = write!(stream, "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: {len}\r\n{cors}\r\n\r\n{err_body}");
						}
					}
				}
			}
			_ => {
				let _ = write!(stream, "HTTP/1.1 404 Not Found\r\n{cors}\r\n\r\n");
			}
		}
	}

	ExitCode::SUCCESS
}
