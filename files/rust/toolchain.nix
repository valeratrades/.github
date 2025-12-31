{
  pkgs,
  channel ? "nightly",
  targets ? [],
  cranelift ? true,
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "${channel}";
  } // (if cranelift then { components = ["rustc-codegen-cranelift-preview"]; } else {})
    // (if targets != [] then { inherit targets; } else {});
}
