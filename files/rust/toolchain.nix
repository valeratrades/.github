{
  pkgs,
  channel ? "nightly",
  targets ? [],
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "${channel}";
		components = "rustc-codegen-cranelift-preview";
  } // (if targets != [] then { inherit targets; } else {});
}
