{
  pkgs,
  ...
}: (pkgs.formats.toml { }).generate "toolchain.toml" {
  toolchain = {
    channel = "nightly";
  };
}
