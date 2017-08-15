"""
    mutable struct CategoricalSummarizer{T} <: Summarizer

Get unique values of a single categorical variable of type T.  

Results will be stored with the key of `:unique` in the schema metadata.
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


is_categorical(s, sch::Data.Schema) = is_categorical(string(s), sch)
is_categorical(s::String, sch::Data.Schema) = is_categorical(Data.types(sch)[sch[s]])
is_categorical(::Type{<:Real}) = false
is_categorical(::Type{Nullable{<:Real}}) = false
is_categorical(::Type) = true
