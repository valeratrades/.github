{
  pkgs,
  toolchain,
  targets ? [],
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "${toolchain}";
  } // (if targets != [] then { inherit targets; } else {});
}
