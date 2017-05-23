module StreamModels

using
    StatsModels,
    DataStreams,
    CategoricalArrays

import StatsModels: ContrastsMatrix, DEFAULT_CONTRASTS, FullDummyCoding

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
          "tupleiterators.jl",
          "stream_utils.jl",
          "set_schema.jl",
          "modelmatrix.jl"])

end # module
