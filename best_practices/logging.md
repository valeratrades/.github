# Emitting logs
- tracing subscriber setup: [my current](<https://github.com/valeratrades/discretionary_engine/blob/master/discretionary_engine/src/utils.rs#L29-L78>)
	although I am yet to figure out how to make tokio console work without trashing my main log (will ping when I do)

	Currently: error layer to dump the panic context before panicking, conditional writing to terminal or file. Currently init like:
	```rs
	let log_path = match std::env::var("TEST_LOG") {
		Ok(_) => None,
		Err(_) => Some(cli.artifacts.0.join(".log").clone().into_boxed_path()),
	};
	utils::init_subscriber(log_path);
	```
- `color-eyre`: `color_eyre::install()?;` somewhere + `RUST_BACKTRACE=1 RUST_LIB_BACKTRACE=0` flags, which make it add backtrace on panic but not on error
	you had a problem with dumb suggestions from it, which is solvable in by configuring cmp, but I haven't yet gotten around to it, will ping when I do.

- `#[instrument]`: absolutely love it, enough to make [this abomination](<https://github.com/valeratrades/rust_codestyle>) to check for missing instruments on functions (buggy, if you start using it, feel free to open issues).

- manual span creation: I found that trying to improve what `#[instrument]` provides by for example delaying filling some of the fields until later in the function to make it more precise, or manually creating spans for say async blocks that you can't automatically derive `#[instrument]` for, reduces iteration speed, so I seldom do it. Plus from readability standpoint, mixing together main logic with adjusting the span is not great.

# Log Levels
From [matklad](<https://matklad.github.io/2024/11/23/semver-is-not-about-you.html>)
- `error` pages the operator immediately.
- `warn` pages if it repeats frequently.
- `info` is what you see in the prog logs when you actively look at them.
- `debug` is what your developers see when they enable extra logging.


# Viewing logs
- popup with expanded info: https://github.com/valeratrades/dots/tree/master/home/v/.config/nvim/after/plugin/log.lua
	uses https://github.com/valeratrades/prettify_log

- highlight: https://github.com/fei6409/log-highlight.nvim

- view ansi characters: https://github.com/Makaze/AnsiEsc
	if you're reading a file being actively streamed into - put it to reload time to time, as some half-finished ascii symbols break it and I haven't yet pinpointed how to fix this

# grepping logs
- [window](<https://github.com/matklad/window>)
	Here is the [article on why](<https://matklad.github.io/2024/02/10/window-live-constant-time-grep.html>)

	I'll make a pull request to add paragraph-based filtering later, will ping you when done
