
> [!WARNING]
> For example \
> Here I could say that \
> This is not actively developed
# readme-fw
![Minimum Supported Rust Version](https://img.shields.io/badge/nightly-1.86+-ab6000.svg)
[<img alt="crates.io" src="https://img.shields.io/crates/v/readme-fw.svg?color=fc8d62&logo=rust" height="20" style=flat-square>](https://crates.io/crates/readme-fw)
[<img alt="docs.rs" src="https://img.shields.io/badge/docs.rs-66c2a5?style=for-the-badge&labelColor=555555&logo=docs.rs&style=flat-square" height="20">](https://docs.rs/readme-fw)
![Lines Of Code](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/valeratrades/b48e6f02c61942200e7d1e3eeabf9bcb/raw/readme-fw-loc.json)
<br>
[<img alt="ci errors" src="https://img.shields.io/github/actions/workflow/status/valeratrades/readme-fw/errors.yml?branch=master&style=for-the-badge&style=flat-square&label=errors&labelColor=420d09" height="20">](https://github.com/valeratrades/readme-fw/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->
[<img alt="ci warnings" src="https://img.shields.io/github/actions/workflow/status/valeratrades/readme-fw/warnings.yml?branch=master&style=for-the-badge&style=flat-square&label=warnings&labelColor=d16002" height="20">](https://github.com/valeratrades/readme-fw/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->

Example utilisation of the framework

and here is a relative link: [some file](./.readme_assets/usage.md).
Notice how you can follow it both from the source file for this section (being [description.md](./.readme_assets/description.md)), and from the compiled README.md.

Test links:
- Inner file (same dir): [inner test file](./.readme_assets/_.test_link_inner.txt)
- Outer file (parent dir): [outer test file](./_.test_link_outter.txt)
- Bare bracket inner: [./.readme_assets/_.test_link_inner.txt]
- Bare bracket outer: [./_.test_link_outter.txt]

### Expected files in `.readme_assets/`

| Pattern | Required | Description |
|---------|----------|-------------|
| `description.(md\|typ)` | Yes | Main project description |
| `warning.(md\|typ)` | No | Warning banner at top of README |
| `usage.(sh\|md\|typ)` | Yes | Usage instructions |
| `installation[-suffix].(sh\|md\|typ)` | No | Installation instructions (collapsible). Suffix becomes title, e.g. `installation-linux.sh` → "Installation: Linux" |
| `other.(md\|typ)` | No | Additional content (roadmap, etc.) |

### Header demotion

All markdown headers (`#`, `##`, etc.) in source files are automatically demoted by one level when rendered into the final README, to fit under the framework's section headers. Exception: `other.(md|typ)` preserves original header levels.
<!-- markdownlint-disable -->
<details>
<summary>
<h3>Installation: Linux Debian</h3>
</summary>

```sh
nix build
```

</details>
<!-- markdownlint-restore -->
<!-- markdownlint-disable -->
<details>
<summary>
<h3>Installation: Windows</h3>
</summary>

Tough luck


</details>
<!-- markdownlint-restore -->
<!-- markdownlint-disable -->
<details>
<summary>
<h3>Installation</h3>
</summary>

``` sh
nix build
```

these days most often it ends up being just that.


</details>
<!-- markdownlint-restore -->

## Usage
```nix
readme = (readme-fw { inherit pkgs; pname = "readme-fw"; lastSupportedVersion = "nightly-1.86"; rootDir = ./.; licenses = [{ name = "Blue Oak 1.0.0"; outPath = "LICENSE"; }]; badges = [ "msrv" "crates_io" "docs_rs" "loc" "ci" ]; }).combined;

devShells.defaut = pkgs.mkShell {
	shellHook = ''
		cp -f ${readme} ./README.md
	'';
}
```

## Roadmap

The `other` section is great for adding random things like that



<br>

<sup>
	This repository follows <a href="https://github.com/valeratrades/.github/tree/master/best_practices">my best practices</a> and <a href="https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md">Tiger Style</a> (except "proper capitalization for acronyms": (VsrState, not VSRState) and formatting).
</sup>

#### License

<sup>
	Licensed under <a href="LICENSE">Blue Oak 1.0.0</a>
</sup>

<br>

<sub>
	Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this crate by you, as defined in the Apache-2.0 license, shall
be licensed as above, without any additional terms or conditions.
</sub>

