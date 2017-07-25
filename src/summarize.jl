# Data summary pass:
#
# Before we can construct some of the term types, we need to know additional
# invariants about the data, like the unique values of categorical data, or
# min/max values for splines.  This pass will consume the data once and compute
# summaries of variables where necessary.
#
# For now, this is just for categorical terms.


"""
    summarize(source::Data.Table, f::Formula)
    summarize!(sch::Data.Schema, source::Data.Table, f::Formula)

Compute summaries of the data from source as necessary to evaluate a formula.
Summaries are stored in the metadata of the schema for source.  This is mediated
by dispatching on the types of the terms and the types of the data via 
`make_summarizer`.
"""
summarize(source::Data.Table, f::Formula) = summarize!(Data.schema(source), source, f)

function summarize!(sch::Data.Schema, source::Data.Table, f::Formula)
    types = Dict(Symbol(k) => Data.types(sch)[sch[k]] for k in Data.header(sch))
    summarizers = unique(reduce(vcat, [], make_summarizer(t, types) for t in f.terms))
    isempty(summarizers) && return sch
    for nt in RowIterator(source)
        for s in summarizers
            update!(s, nt)
        end
    end
    summaries = Dict()
    for s in summarizers
        push!(get!(Dict, summaries, name(s)), get(s))
    end
    sch.metadata[:summaries] = summaries
    return sch
end





# generate summarizers for each term and collect into a Vector to save on schema
# metadata.

"""
    make_summarizer(term::T, types::Dict{Symbol,Type}) where T<:Terms.Term

Create a `Summarizer` for a term, given the types of the data.
"""
make_summarizer(term::Terms.Term, types::Dict) = []
make_summarizer(term::Terms.Eval, types::Dict) =
    is_categorical(types[term.name]) ?
    CategoricalSummarizer{types[term.name]}(term.name) :
    []
make_summarizer(term::Terms.Interaction, types::Dict) =
    mapreduce(t -> make_summarizer(t, types), vcat, [], term.terms)


abstract type Summarizer end
"""
    update!(s::Summarizer, nt::NamdedTuple)

Update the summary statistics with a named tuple of one row of data.
"""

function update!(::Summarizer, nt) end
"""
    get(s::Summarizer)

Extract the summary statistics from a summarizer.  Returns a stat-value `Pair`.
"""

function Base.get(::Summarizer) end
"""
    name(s::Summarizer)

The name of the variable(s) summarized.
"""
name(s::Summarizer) = s.name


"""
    mutable struct CategoricalSummarizer{T} <: Summarizer

Get unique values of a single categorical variable of type T.
"""
mutable struct CategoricalSummarizer{T} <: Summarizer
    name::Symbol
    seen::Set{T}
    uniq::Vector{T}
end

CategoricalSummarizer{T}(name::Symbol) where T = CategoricalSummarizer(name, Set{T}(), T[])

function update!(cs::CategoricalSummarizer{T}, nt) where T
    x = nt[cs.name]::T
    if x ∉ cs.seen
        push!(cs.seen, x)
        push!(cs.uniq, x)
    end
    cs
end

"""
    get(cs::CategoricalSummarizer{T}) = :unique => T[values...]
"""
Base.get(cs::CategoricalSummarizer) = :unique => cs.uniq

Base.hash(cs::CategoricalSummarizer, h::UInt64) = hash(typeof(cs), hash(cs.name, h))
Base.:(==)(c1::CategoricalSummarizer, c2::CategoricalSummarizer) = c1.name == c2.name



# is_categorical(s, sch::Data.Schema) = is_categorical(string(s), sch)
# is_categorical(s::String, sch::Data.Schema) = is_categorical(Data.types(sch)[sch[s]])
is_categorical(::Type{<:Real}) = false
is_categorical(::Type{Nullable{<:Real}}) = false
is_categorical(::Type) = true
