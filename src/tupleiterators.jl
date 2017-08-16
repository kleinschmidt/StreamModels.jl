# contributed by Jacob Quinn: iterator of NamedTuples from a Data.Table source.

mutable struct RowIterator{names,T}
    nt::NamedTuple{names, T}
end
Base.start(ri::RowIterator) = 1
Base.done(ri::RowIterator, i::Int) = i > length(getfield(ri.nt, 1))
Base.length(ri::RowIterator) = length(ri.nt[1])

Data.schema(ri::RowIterator) = Data.schema(ri.nt)

@generated function Base.next(ri::RowIterator{names,T}, row::Int) where {names, T}
    NT = NamedTuple{names}
    S = Tuple{map(eltype, T.parameters)...}
    r = :(Base.namedtuple($NT, convert($S, tuple($((:($(Symbol("v$i")) = getfield(ri.nt, $i)[row]; $(Symbol("v$i")) isa Null ? null : $(Symbol("v$i"))) for i = 1:nfields(T))...)))...))
    return :(($r, row+1))
end



# mutable struct NamedTupleIterator{R,Ts,names}
#     iter::TupleIterator
# end

# Base.start(nti::NamedTupleIterator) = start(nti.iter)
# Base.done(nti::NamedTupleIterator, i::Int) = done(nti.iter, i)
# function Base.next(nti::NamedTupleIterator{R, Ts, names}, row::Int) where {R, Ts, names}
#     Base.namedtuple(names, next(nti.iter, row)...)
# end
