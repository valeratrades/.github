	// Check that all #[deprecated] items have been removed by this version
	let pkg_version = env!("CARGO_PKG_VERSION");
	let current = parse_semver(pkg_version);
	let deprecate_at = parse_semver(DEPRECATE_AT_VERSION);

	if current >= deprecate_at {
		let src_dir = std::path::Path::new("src");
		if src_dir.exists() {
			let mut deprecated_locations = Vec::new();
			find_deprecated_attrs(src_dir, &mut deprecated_locations);

			if !deprecated_locations.is_empty() {
				eprintln!("\n\x1b[1;31mDeprecated items found!\x1b[0m");
				eprintln!("All #[deprecated] items must be removed by version {}:\n", DEPRECATE_AT_VERSION);
				for loc in &deprecated_locations {
					eprintln!("  - {}", loc);
				}
				eprintln!("\nRemove these items before proceeding with version {}.", pkg_version);
				panic!("Deprecated items must be removed");
			}
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

fn find_deprecated_attrs(dir: &std::path::Path, locations: &mut Vec<String>) {
	let Ok(entries) = std::fs::read_dir(dir) else {
		return;
	};

	for entry in entries.flatten() {
		let path = entry.path();
		if path.is_dir() {
			find_deprecated_attrs(&path, locations);
		} else if path.extension().is_some_and(|ext| ext == "rs") {
			if let Ok(content) = std::fs::read_to_string(&path) {
				for (line_num, line) in content.lines().enumerate() {
					let trimmed = line.trim_start();
					if trimmed.starts_with("#[deprecated") || trimmed.starts_with("#[allow(deprecated") {
						locations.push(format!("{}:{}", path.display(), line_num + 1));
					}
				}
			}
		}
	}
