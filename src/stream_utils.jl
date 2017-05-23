## until these are defined in the Data.Source interface, use the reset! method
## to get non-random-access data sources ready to stream.
reset!(x) = x
reset!(x::TupleIterator) = reset!(x.source)


"""
    get_unique!(sch::Data.Schema, source, cols::Vector{Int})
    get_unique!(sch::Data.Schema, source, cols::Vector)

Get the unique values of `col` from source, making a single pass through the
data, and store in the schema metadata.  Columns can be specified by number, or
else are first converted to strings and the column number looked up in the
schema.

These methods modify the metadata of the schema they are given.
"""
function get_unique!(sch::Data.Schema, source, cols::Vector{Int})
    reset!(source)
    types = Data.types(sch)
    uniqs = [Vector{types[i]}() for i in cols]
    seens = [Set{types[i]}() for i in cols]
    row = 1
    N = size(sch, 2)
    while !Data.isdone(source, row, 1)
        row_tup = ntuple(N) do i
            Data.streamfrom(source, Data.Field, types[i], row, i)
        end
        for (i,col) in enumerate(cols)
            x = row_tup[col]
            if !(x in seens[i])
                push!(seens[i], x)
                push!(uniqs[i], x)
            end
        end
        row += 1
    end
    uniq_dict = get!(sch.metadata, :unique, Dict())
    header = Data.header(sch)
    for (col, uniq) in zip(cols, uniqs)
        uniq_dict[header[col]] = uniq
    end
    sch
end

get_unique!(sch::Data.Schema, source, cols::Vector) =
    get_unique!(sch, source, [sch[string(c)] for c in cols])

"""
    get_unique(source, cols::Vector)

Get unique values from a Data.Source for the given columns, and save them in
the metadata of the returned Data.Schema.
"""
get_unique(source, cols::Vector) = get_unique!(Data.schema(source), source, cols)
