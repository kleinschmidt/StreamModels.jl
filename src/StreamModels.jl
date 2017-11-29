module StreamModels

using
    StatsBase,
    DataStreams,
    CategoricalArrays,
    ArgCheck,
    Compat,
    Missings

using CategoricalArrays: CategoricalPool

export
    ModelBuilder,
    Terms,
    Formula,
    @formula,
    modelmatrix,
    @model,
    build,

    AbstractContrasts,
    EffectsCoding,
    DummyCoding,
    HelmertCoding,
    ContrastsCoding


function name end

const DEBUG = true

macro debug(msg)
    DEBUG ? :(println(string($(esc(msg))))) : nothing
end

include("typedefs.jl")
include("contrasts.jl")
include("utils.jl")
include("terms.jl")
include("formula.jl")
include("summarize/summarize.jl")
include("set_schema.jl")
include("modelmatrix.jl")
include("model.jl")

end # module
