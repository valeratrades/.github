Example utilisation of the framework

and here is a relative link: [some file](./usage.md).
Notice how you can follow it both from the source file for this section (being [description.md](./description.md)), and from the compiled README.md.
// One thing it can't do is link up, but I argue that's a bad idea anyways.

## Expected files in `.readme_assets/`

| Pattern | Required | Description |
|---------|----------|-------------|
| `description.(md\|typ)` | Yes | Main project description |
| `warning.(md\|typ)` | No | Warning banner at top of README |
| `usage.(sh\|md\|typ)` | Yes | Usage instructions |
| `installation[-suffix].(sh\|md\|typ)` | No | Installation instructions (collapsible). Suffix becomes title, e.g. `installation-linux.sh` → "Installation: Linux" |
| `other.(md\|typ)` | No | Additional content (roadmap, etc.) |

## Header demotion

All markdown headers (`#`, `##`, etc.) in source files are automatically demoted by one level when rendered into the final README, to fit under the framework's section headers. Exception: `other.(md|typ)` preserves original header levels.
