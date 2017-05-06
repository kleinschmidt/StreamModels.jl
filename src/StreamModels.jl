module StreamModels

using
    StatsModels,
    DataStreams

export
    Formula,
    @formula,
    parse!

# package code goes here
include.(["formula.jl",
          "set_schema.jl"])

end # module
