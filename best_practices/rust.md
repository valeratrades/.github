# Libs
all my libs should define duration in terms of `std::time::Duration`. Even if it's always going to be used alongside `jiff` and converted to its duration type, unless the lib itself makes use of `jiff`, its duration type is that of std.
