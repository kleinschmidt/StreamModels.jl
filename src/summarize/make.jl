# generate summarizers for each term and collect into a Vector to save on schema
# metadata.

"""
    make_summarizer(term::T, types::Dict{Symbol,Type}) where T<:Terms.Term

Create a `Summarizer` for a term, given the types of the data.  If no summaries 
are needed, this method should return an empty array `[]`.
"""
make_summarizer(term::Terms.Term, types::Dict) = []
make_summarizer(term::Terms.Eval, types::Dict) =
    is_categorical(types[term.name]) ?
    CategoricalSummarizer{types[term.name]}(term.name) :
    []
make_summarizer(term::Terms.Interaction, types::Dict) =
    mapreduce(t -> make_summarizer(t, types), vcat, [], term.terms)

