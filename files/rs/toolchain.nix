{
  pkgs,
  toolchain,
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "${toolchain}";
  };
}
