module StreamModels

using
    StatsModels,
    DataStreams

import StatsModels: ContrastsMatrix, DEFAULT_CONTRASTS, FullDummyCoding

export
    Formula,
    @formula,
    parse!

# package code goes here
include.(["formula.jl",
          "set_schema.jl"])

end # module
