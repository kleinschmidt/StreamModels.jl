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


function name end

const DEBUG = false

macro debug(msg)
    DEBUG ? :(println(string($(esc(msg))))) : nothing
end

include("typedefs.jl")
include("terms.jl")
include("formula.jl")
include("summarize/summarize.jl")
include("tupleiterators.jl")
include("set_schema.jl")

end # module
