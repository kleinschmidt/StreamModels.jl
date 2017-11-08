# strategy:
# * @model macro converts formula exprs in original callinto Formula calls and
#   plugs into ModelBuilder{M} where M is the original call
# * If provided data, calls ModelFrame{M} constructor with builder and data.
#   This summarizes and then sets schema on all the formulas in args/kw, 

mutable struct ModelBuilder{M}
    args::Tuple
    kw::Dict{Symbol,Any}
    formula_idx::Vector{Int}
    formula_kws::Vector{Symbol}
end

ModelBuilder(head, args...; kw...) = ModelBuilder{head}(args, Dict(kw))
function ModelBuilder{M}(args::Tuple, kw::Dict) where M
    formula_idx = find(x -> x isa Formula, args)
    formula_kws = Symbol[k for (k,v) in kw if isa(v, Formula)]
    ModelBuilder{M}(args, kw, formula_idx, formula_kws)
end

_replace_formula!(x) = x
function _replace_formula!(ex::Expr)
    if Meta.isexpr(ex, :kw)
        ex.args[2] = _replace_formula!(ex.args[2])
        return ex
    end

    if is_formula(ex)
        return _formula!(ex)
    else
        return ex
    end
end

"""
    @model f(args...; kw...)

Capture formula arguments to a model constructor (or any other) function, and
transform to a `ModelBuilder` constructor with `Formula`s in their place.

"""
macro model(ex)
    @argcheck check_call(ex)
    # strategy is to replace each argument that's a formula with an expr for a
    # formula, then plug into a call to ModelBuilder
    builder = Expr(:call, :(StreamModels.ModelBuilder), ex.args[1],
                   _replace_formula!.(ex.args[2:end])...)
    # prevent macro hygine from transforming captured variables to refer to
    # `StatsModels`
    return esc(builder)
end


"""
    build(builder::ModelBuilder{M}, source) where M
    build(builder::ModelBuilder{M}, source, schema::Data.Schema) where M

Construct a model of type M from a model builder and a data source.  This
extracts the Formula [keyword] arguments, sets the schema on them, performs any
necessary summarization, and instantiates them as numeric arrays, before calling
the constructor.

"""
function build(builder::ModelBuilder{M}, source) where M
    
end


"""
    predict(mf::ModelFrame)

Predicted values for the model (needs to be fitted first; just delegates to the
stored model

"""
function StatsBase.predict(mf::ModelFrame) = predict(mf.model) end


"""
    predict(mf::ModelFrame{M,S}, source::S) where {M,S}

Generate predictions for new data.  The source is converted into numeric
arguments and plugged in in the same order they occur in the builder, without
the non-formula arguments.

Packages can customize this behavior by specializing on the model type.

"""
function StatsBase.predict(mf::ModelFrame{M,S}, source::S) where {M,S} end

# mutable struct ModelFrame{M,S}
#     model::M
#     source::S
#     schema::Data.Schema
# end

