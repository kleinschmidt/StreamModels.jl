module StreamModels

using
    StatsModels,
    StatsBase,
    DataStreams,
    CategoricalArrays,
    ArgCheck,
    Compat,
    Nulls

using StatsModels: ContrastsMatrix, DEFAULT_CONTRASTS, FullDummyCoding
using CategoricalArrays: CategoricalPool

export
    ModelBuilder,
    ModelFrame,
    Terms,
    Formula,
    @formula,
    modelmatrix,
    @model,
    build


function name end

const DEBUG = true

macro debug(msg)
    DEBUG ? :(println(string($(esc(msg))))) : nothing
end

include("typedefs.jl")
include("utils.jl")
include("terms.jl")
include("formula.jl")
include("summarize/summarize.jl")
include("tupleiterators.jl")
include("set_schema.jl")
include("modelmatrix.jl")
include("model.jl")

end # module
