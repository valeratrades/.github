# Lexicon
set of conventions with aim to disambiguate the struct/variable naming in projects, promoting consistency.


## `Deref`-able struct field naming
main wrapped field of a Newtype-ish struct is named `v`, not the duplicate of the wrapper's name. So have
```rs
#[derive(derive_more::Deref)]
struct Klines {
	#[deref]
	v: Vec<Kline>, // as opposed to naming this field `klines`
	tf: Timeframe,
}
```
Because that would be a minor code duplication. And the standard to mirror the parent is not adapted universally throughout the languages, so it's (? is it?) fine for me to break it.

## Settings
"config" refers to the written specifications that _init_ the project's "settings" or a part of them
"cli args" refers to, well, command line arguments
"env" here refers to anything and everything we pick up from environment
and now "settings" refers to all the things the projects refers to at runtime to determine behavior. They can be constructed from either one or a combination of "config", "args", "env". They can have their state changed at runtime, and even persist it over to the next session, overriding values in "config"

## Words in text
### or/xor
Any instance of "or" in text signify what's commonly written as "or/and" and is pure logical `OR`. Common utilisation of "or" to mean `XOR` is always written as, well, "xor".
Similarly, "OR"/"XOR" could be used interchangeably with lowercase versions; only reason for utilisation being ease of visual parsing.

### ex/eg/ie
For starters: don't add punctuation around these abbreviations. They are written exactly as follows: "ex", "eg", "ie"; without punctuation inside or after (like conventional {"ex:", "e.g.,", etc} writing assumes).
Now meaning: "eg" and "ie" are special cases of "ex", only providing additional information on scope:
- "ie": exactly one example
- "eg": more than one example
- "ex": no information on total number of possible examples
