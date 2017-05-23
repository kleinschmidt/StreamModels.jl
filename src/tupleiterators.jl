abstract TupleIterator

"""
    FieldTupleIterator

An iterator that wraps a Data.Source supporting Data.Field streaming, and
generates a sequence of tuples of rows.
"""
type FieldTupleIterator{R,Ts,N} <: TupleIterator
    source
    schema::Data.Schema{R}
    state::Int
end

function FieldTupleIterator{R}(source, schema::Data.Schema{R})
    N = size(schema,2)
    Ts = Tuple{schema.types...}
    FieldTupleIterator{R, Ts, N}(source, schema, 1)
end

Base.start(::FieldTupleIterator) = 1
Base.done(iter::FieldTupleIterator, state::Int) = Data.isdone(iter.source, state, 1)
function Base.next{R,Ts,N}(iter::FieldTupleIterator{R,Ts,N}, state::Int)
    t = ntuple(N) do i
        Data.streamfrom(iter.source,
                        Data.Field,
                        iter.schema.types[i],
                        state, i)
    end
    t, state+1
end

Base.length(iter::FieldTupleIterator{true}) = size(iter.schema, 1)
Base.eltype{R,Ts,N}(::Type{FieldTupleIterator{R,Ts,N}}) = Ts



"""
    ColumnTupleIterator

An iterator that wraps a Data.Source supporting Data.Column streaming, and
generates a series of tuples of rows.  It does this by streaming all the columns
into memory and then zipping them together, so if you don't want to have
everything in memory at once then use a `FieldTupleIterator`

"""

type ColumnTupleIterator{R,Ts,N} <: TupleIterator
    source::Any
    schema::Data.Schema{R}
    iter::Any
    state::Int
end

function ColumnTupleIterator{R}(source, schema::Data.Schema{R})
    N = size(schema,2)
    cols = (Data.streamfrom(source, Data.Column, schema.types[i], i) for i in 1:N)
    iter = zip(cols...)
    Ts = eltype(iter)
    ColumnTupleIterator{R, Ts, N}(source, schema, iter, 1)
end

Base.start(iter::ColumnTupleIterator) = 1
Base.done(iter::ColumnTupleIterator, state) = done(iter.iter, state)
Base.next(iter::ColumnTupleIterator, state) = next(iter.iter, state)
Base.length(iter::ColumnTupleIterator{true}) = length(iter.iter)
Base.eltype{R,Ts,N}(::Type{ColumnTupleIterator{R,Ts,N}}) = Ts


tuple_iterator{T}(source::T) =
    Data.streamtype(T, Data.Field) ?
    tuple_iterator(source, Data.Field) :
    Data.streamtype(T, Data.Column) ?
    tuple_iterator(source, Data.Column) :
    error("Source $T does not support either Field or Column streaming")
tuple_iterator(source, ::Type{Data.Field}) = FieldTupleIterator(source, Data.schema(source))
tuple_iterator(source, ::Type{Data.Column}) = ColumnTupleIterator(source, Data.schema(source))


# type NoNullTupleIterator{R,Ts,N} <: TupleIterator
#     iter::TupleIterator{R,Ts,N}
#     cols_no_null::Vector{Int}
# end

# NoNullTupleIterator{R,Ts,N}(iter::TupleIterator{R,Ts,N}) = NoNullTupleIterator(iter, 1:N)
# function NoNullTupleIterator(iter::TupleIterator, cols::Vector)
#     col_nums = [iter.schema[string(c)] for c in cols]
#     NoNullTupleIterator(iter, col_nums)
# end

# Base.start(iter::NN) = start(iter.iter)
# Base.done(iter::NN) = 
