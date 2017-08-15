# Data summary pass:
#
# Before we can construct some of the term types, we need to know additional
# invariants about the data, like the unique values of categorical data, or
# min/max values for splines.  This pass will consume the data once and compute
# summaries of variables where necessary.
#
# For now, this is just for categorical terms.


include("abstract.jl")
include("categorical.jl")
include("make.jl")
include("run.jl")

# TODO: use OnlineStatsBase.jl API: replace Summarizer with OnlineStat, which
# needs to provide a fit!, merge, and _value method.
