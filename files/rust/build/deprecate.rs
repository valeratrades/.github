	// Check that all #[deprecated] items have been removed by their specified version
	let pkg_version = env!("CARGO_PKG_VERSION");
	let current = parse_semver(pkg_version);
	let default_deprecate_at = parse_semver(DEPRECATE_AT_VERSION);

	let src_dir = std::path::Path::new("src");
	if src_dir.exists() {
		let mut expired_items = Vec::new();
		find_deprecated_attrs(src_dir, current, default_deprecate_at, &mut expired_items);

		if !expired_items.is_empty() {
			eprintln!("\n\x1b[1;31mDeprecated items past their removal deadline!\x1b[0m\n");
			for (loc, version) in &expired_items {
				eprintln!("  - {} (should be removed by {})", loc, version);
			}
			eprintln!("\nRemove these items before proceeding with version {}.", pkg_version);
			panic!("Deprecated items must be removed");
		}
	}
}

/// Parse a semver version string, handling optional 'v' prefix.
fn parse_semver(version: &str) -> (u32, u32, u32) {
	let version = version.strip_prefix('v').unwrap_or(version);
	let parts: Vec<&str> = version.split('.').collect();
	let major = parts.first().and_then(|s| s.parse().ok()).unwrap_or(0);
	let minor = parts.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);
	let patch = parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
	(major, minor, patch)
}

fn find_deprecated_attrs(
	dir: &std::path::Path,
	current: (u32, u32, u32),
	default_deprecate_at: (u32, u32, u32),
	expired: &mut Vec<(String, String)>,
) {
	let Ok(entries) = std::fs::read_dir(dir) else {
		return;
	};

	for entry in entries.flatten() {
		let path = entry.path();
		if path.is_dir() {
			find_deprecated_attrs(&path, current, default_deprecate_at, expired);
		} else if path.extension().is_some_and(|ext| ext == "rs") {
			if let Ok(content) = std::fs::read_to_string(&path) {
				for (line_num, line) in content.lines().enumerate() {
					let trimmed = line.trim_start();
					if trimmed.starts_with("#[deprecated") {
						let (deprecate_at, version_str) = extract_since(trimmed)
							.map(|s| (parse_semver(s), s.to_string()))
							.unwrap_or((default_deprecate_at, DEPRECATE_AT_VERSION.to_string()));
						if current >= deprecate_at {
							expired.push((format!("{}:{}", path.display(), line_num + 1), version_str));
						}
					} else if trimmed.starts_with("#[allow(deprecated") {
						// #[allow(deprecated)] should always be removed by default version
						if current >= default_deprecate_at {
							expired.push((format!("{}:{}", path.display(), line_num + 1), DEPRECATE_AT_VERSION.to_string()));
						}
					}
				}
			}
		}
	}
}

/// Extract the `since` value from a #[deprecated(since = "...")] attribute
fn extract_since(attr: &str) -> Option<&str> {
	let start = attr.find("since")? + 5;
	let rest = &attr[start..];
	let rest = rest.trim_start();
	let rest = rest.strip_prefix('=')?;
	let rest = rest.trim_start();
	let quote_char = rest.chars().next()?;
	if quote_char != '"' {
		return None;
	}
	let rest = &rest[1..];
	let end = rest.find('"')?;
	Some(&rest[..end])
}
