# Libs
all my libs should define duration in terms of `std::time::Duration`. Even if it's always going to be used alongside `chrono` and converted to its duration type, unless the lib itself makes use of chrono, its duration type is that of std.
