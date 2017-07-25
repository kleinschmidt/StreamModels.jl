# Data summary pass:
#
# Before we can construct some of the term types, we need to know additional
# invariants about the data, like the unique values of categorical data, or
# min/max values for splines.  This pass will consume the data once and compute
# summaries of variables where necessary.
#
# For now, this is just for categorical terms.



# generate summarizers for each term and collect into a Vector to save on schema
# metadata.

make_summarizer(term::Terms.Term, types::Dict) = []
make_summarizer(term::Terms.Eval, types::Dict) =
    is_categorical(types[term.name]) ?
    CategoricalSummarizer{types[term.name]}(term.name) :
    []
make_summarizer(term::Terms.Interaction, types::Dict) =
    mapreduce(t -> make_summarizer(t, types), vcat, [], term.terms)



mutable struct CategoricalSummarizer{T}
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

Base.hash(cs::CategoricalSummarizer, h::UInt64) = hash(typeof(cs), hash(cs.name, h))
Base.:(==)(c1::CategoricalSummarizer, c2::CategoricalSummarizer) = c1.name == c2.name



# is_categorical(s, sch::Data.Schema) = is_categorical(string(s), sch)
# is_categorical(s::String, sch::Data.Schema) = is_categorical(Data.types(sch)[sch[s]])
is_categorical(::Type{<:Real}) = false
is_categorical(::Type{Nullable{<:Real}}) = false
is_categorical(::Type) = true
