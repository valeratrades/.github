First, a build system is a bootstrap process: it is how you get from git clone to a working binary. The two aspects of this boostrapping process are important:

- It should be simple. No
```sh
sudo apt-get install bazzilion packages,
```
- the single binary of your build system should be able to bring everything else that’s needed, automatically.
- It should be repeatable. Your laptop and your CI should end up with exactly identical set of dependencies. The end result should be a function of commit hash, and not your local shell history, otherwise NRSR doesn't work.
Second, a build system is developer UI. To do almost anything, you need to type some sort of build system invocation into your shell. There should be a single, clearly documented command for building and testing the project. If it is not a single makebelieve test, something’s wrong.

One anti-pattern here is when the build system spills over to CI. When, to figure out what the set of checks even is, you need to read .github/workflows/\*.yml to compile a list of commands. That’s accidental complexity! Sprawling yamls are a bad entry point. Put all the logic into the build system and let the CI drive that, and not vice verse.

[There is a stronger version of the advice](<https://matklad.github.io/2023/12/31/O(1)-build-file.html>)
. No matter the size of the project, there’s probably only a handful of workflows that make sense for it: testing, running, releasing, etc. This small set of workflows should be nailed from the start, and specific commands should be documented. When the project subsequently grows in volumes, this set of build-system entry points should not grow.

If you add a Frobnicator, makebelieve test invocation should test that Frobnicator works. If instead you need a dedicated makebelieve test-frobnicator and the corresponding line in some CI yaml, you are on a perilous path.

Finally, a build system is a collection of commands to make stuff happen. In larger projects, you’ll inevitably need some non-trivial amount of glue automation. Even if the entry point is just makebelive release, internally that might require any number of different tools to build, sign, tag, upload, validate, and generate a changelog for a new release.

A common anti-pattern is to write these sorts of automations in bash and Python, but that’s almost pure technical debt. These ecosystems are extremely finnicky in and off themselves, and, crucially (unless your project itself is written in bash or Python), they are a second ecosystem to what you already have in your project for “normal” code.

But releasing software is also just code, which you can write in your primary language. The right tool for the job is often the tool you are already using. It pays off to explicitly attack the problem of glue from the start, and to pick/write a library that makes writing subprocess wrangling logic easy.

Summing the build and CI story up:

Build system is self-contained, reproducible and takes on the task of downloading all external dependencies. Irrespective of size of the project, it contains O(1) different entry points. One of those entry points is triggered by the not rocket science rule CI infra to run the set of canonical checks. There’s an explicit support for free-form automation, which is implemented in the same language as the bulk of the project.
