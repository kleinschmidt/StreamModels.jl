module StreamModels

using
    StatsModels,
    DataStreams,
    CategoricalArrays,
    ArgCheck

using StatsModels: ContrastsMatrix, DEFAULT_CONTRASTS, FullDummyCoding
using CategoricalArrays: CategoricalPool

export
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

include.(["typedefs.jl",
          "formula.jl",
          "nulls_hack.jl",
          "tupleiterators.jl",
          "stream_utils.jl",
          "set_schema.jl",
          "anonfactory.jl",
          "modelmatrix.jl"])

end # module
