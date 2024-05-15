Document stylistic details pertaining to git. If project uses area: prefixes for commits, spell out an explicit list of such prefixes.

Consider documenting acceptable line length for the summary line. Git man page boldly declares that a summary should be under 50 characters, but that is just plain false. Even in the kernel, most summaries are somewhere between 50 and 80 characters.

Definitely explicitly forbid adding large files to git. Repository size increases monotonically, git clone time is important.

Document merge-vs-rebase thing. My preferred answer is:

- A unit of change is a pull request, which might contain several commits
- Merge commit for the pull request is what is being tested
- The main branch contains only merge commits
- Conversely, _only_ the main branch contains merge commits, pull requests themselves are always rebased.

Forbidding large files in the repo is a good policy, but it’s hard to follow. Over the lifetime of the project, someone somewhere will sneakily add and revert a megabyte of generated protobufs, and that will fly under code review radar.
