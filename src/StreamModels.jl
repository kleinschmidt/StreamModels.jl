module StreamModels

using
    StatsModels,
    DataStreams,
    CategoricalArrays,
    ArgCheck,
    Compat,
    Nulls

using StatsModels: ContrastsMatrix, DEFAULT_CONTRASTS, FullDummyCoding
using CategoricalArrays: CategoricalPool

export
    Terms,
    Formula,
    @formula,
    parse!,
    reset!,
    modelmatrix

# package code goes here

const DEBUG = false

macro debug(msg)
    DEBUG ? :(println(string($(esc(msg))))) : nothing
end

include("typedefs.jl")
include("terms.jl")
include("formula.jl")
include("summarize/summarize.jl")
include("tupleiterators.jl")

end # module
