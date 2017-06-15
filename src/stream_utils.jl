## until these are defined in the Data.Source interface, use the reset! method
## to get non-random-access data sources ready to stream.
reset!(x) = x
reset!(x::TupleIterator) = reset!(x.source)

"""
    get_unique!(iter::TupleIterator, cols::Vector{Int})

Update the schema stored on `iter` with the unique values for the specified
columns.  The unique values are stored in a Dict in the metadata field of the
underlying schema.  `iter` is reset before and after this operation.

"""
function get_unique!{T<:Integer}(iter::TupleIterator, cols::Vector{T})
    reset!(iter)
    types = Data.types(iter)
    uniqs = [Vector{types[i]}() for i in cols]
    seens = [Set{types[i]}() for i in cols]

    for t in iter
        for (i,col) in enumerate(cols)
            x = t[col]
            if !(x in seens[i])
                push!(seens[i], x)
                push!(uniqs[i], x)
            end
        end
    end

    sch = Data.schema(iter)

    uniq_dict = get!(sch.metadata, :unique, Dict())
    header = Data.header(sch)
    for (col, uniq) in zip(cols, uniqs)
        uniq_dict[header[col]] = uniq
    end

    reset!(iter)
    iter
end

get_unique!(iter::TupleIterator, cols::Vector) =
    (sch = Data.schema(iter); get_unique!(iter, [sch[string(c)] for c in cols]))
