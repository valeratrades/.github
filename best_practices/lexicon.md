# Lexicon
set of conventions with aim to disambiguate the struct/variable naming in projects, promoting consistency.

# Settings
"config" refers to the written specifications that _init_ the project's "settings" or a part of them
"cli args" refers to, well, command line arguments
"env" here refers to anything and everything we pick up from environment
and now "settings" refers to all the things the projects refers to at runtime to determine behavior. They can be constructed from either one or a combination of "config", "args", "env". They can have their state changed at runtime, and even persist it over to the next session, overriding values in "config"
