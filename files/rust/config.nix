{ pkgs }:
(pkgs.formats.toml { }).generate "config.toml" {
  target."x86_64-unknown-linux-gnu".rustflags = [
    "-C" "link-arg=-fuse-ld=mold"
    "--cfg" "tokio_unstable"
    "-Z" "threads=8"
    "-Z" "track-diagnostics"
		"--cfg" "web_sys_unstable_apis"
		#"--cfg" "procmacro2_semver_exempt"
  ];
	profile = {
		rust = {
			codegen-backend = "cranelift";
		};
	};
}
