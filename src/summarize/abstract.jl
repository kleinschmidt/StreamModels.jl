
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

The name of the variable(s) summarized.  Defaults to the `name` field.
"""
name(s::Summarizer) = s.name
