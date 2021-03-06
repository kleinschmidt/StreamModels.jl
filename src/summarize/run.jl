"""
    summarize(source::Data.Table, f::Formula)
    summarize!(sch::Data.Schema, source::Data.Table, f::Formula)

Compute summaries of the data from source as necessary to evaluate a formula.
Summaries are stored in the metadata of the schema for source.  This is mediated
by dispatching on the types of the terms and the types of the data via 
`make_summarizer`.
"""
summarize(source::Data.Table, fs::Formula...) = summarize!(Data.schema(source), source, fs...)

function summarize!(sch::Data.Schema, source::Data.Table, fs::Formula...)
    terms = mapreduce(f->f.term.rhs, vcat, [], fs)
    types = Dict(Symbol(k) => Data.types(sch)[sch[k]] for k in Data.header(sch))
    summarizers = unique(reduce(vcat, [], make_summarizer(t, types) for t in terms))
    isempty(summarizers) && return sch
    for nt in Data.rows(source)
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


