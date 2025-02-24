> [!WARNING]
> For example \
> Here I could say that \
> This is not actively developed

# readme-fw
![Minimum Supported Rust Version](https://img.shields.io/badge/nightly-1.86+-ab6000.svg)
[<img alt="crates.io" src="https://img.shields.io/crates/v/readme-fw.svg?color=fc8d62&logo=rust" height="20" style=flat-square>](https://crates.io/crates/readme-fw)
[<img alt="docs.rs" src="https://img.shields.io/badge/docs.rs-66c2a5?style=for-the-badge&labelColor=555555&logo=docs.rs&style=flat-square" height="20">](https://docs.rs/readme-fw)
![Lines Of Code](https://img.shields.io/badge/LoC-184-lightblue)
<br>
[<img alt="ci errors" src="https://img.shields.io/github/actions/workflow/status/valeratrades/readme-fw/errors.yml?branch=master&style=for-the-badge&style=flat-square&label=errors&labelColor=420d09" height="20">](https://github.com/valeratrades/readme-fw/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->
[<img alt="ci warnings" src="https://img.shields.io/github/actions/workflow/status/valeratrades/readme-fw/warnings.yml?branch=master&style=for-the-badge&style=flat-square&label=warnings&labelColor=d16002" height="20">](https://github.com/valeratrades/readme-fw/actions?query=branch%3Amaster) <!--NB: Won't find it if repo is private-->

Example utilisation of the framework

and here is a relative link: [some file](./.readme_assets/usage.md).
Notice how you can follow it both from the source file for this section (being [description.md](./.readme_assets/description.md)), and from the compiled README.md.
// One thing it can't do is link up, but I argue that's a bad idea anyways.

<!-- markdownlint-disable -->
<details>
  <summary>
    <h2>Installation</h2>
  </summary>
  <pre>
    <code class="language-sh">nix build # these days most often it ends up being just that.
#Q: could potentially expand to parsing for `./installation.md` too, if found, include that instead, so that I could nest installation instructions for other OSes</code></pre>
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
