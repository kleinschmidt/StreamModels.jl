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
    modelmatrix

# package code goes here
include.(["formula.jl",
          "set_schema.jl",
          "modelmatrix.jl"])

end # module
