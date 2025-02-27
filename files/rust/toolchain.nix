{
  pkgs,
  toolchain,
  targets ? [],
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "${toolchain}";
		components = "rustc-codegen-cranelift-preview";
  } // (if targets != [] then { inherit targets; } else {});
}
