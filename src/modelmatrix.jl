# once schema is set in formula, we can generate code to fill in the model
# matrix row-by-row.  how we do this depends on the streaming type of the
# source.  if we can get whole columns at a time, then we can efficiently
# convert categorical columns to efficient categorical variables.  otherwise, we
# have to do something like a dictionary lookup for each element.
#
# actually, I don't think it's any more efficient to convert a whole column at a
# time, if you already know the unique elements.  and it might even be possible
# to convert to the ref value in the tuple construction; then the anonymous
# function only needs to get the relevant row in the contrasts matrix.  not
# clear how much that buys us but it might simplify the code generating bit.
#
# so we have a Data.Schema and a Formula with the RHS with leaf nodes converted
# to Categorical/ContinuousTerms.  from this, need to generate two things:
# 
# 1. tuple factory that takes a Data.Source and creates a tuple iterator
# 2. function that takes one tuple and returns one model matrix row


"""
    StreamColIterator(source::Data.Source, schema::Data.Schema, col::Int)

An iterator that wraps a single column of a streaming data source.  We can zip these
together to create a tuple iterator.
"""

type StreamColIterator{T,R}
    source::Any
    schema::Data.Schema{R}
    col::Int
end

Base.start(::StreamColIterator) = 1
Base.done(iter::StreamColIterator, state::Int) = Data.isdone(iter.source, state, iter.col)
Base.next{T}(iter::StreamColIterator{T}, state::Int) = 
    Data.streamfrom(iter.source, Data.Field, T, state, iter.col), state+1

StreamColIterator{R}(source, schema::Data.Schema{R}, col::Int) =
    StreamColIterator{schema.types[col], R}(source, schema, col)

Base.length{T}(iter::StreamColIterator{T,true}) = size(iter.schema, 1)
Base.eltype{T,R}(::Type{StreamColIterator{T,R}}) = T









"""
    StreamTupleIterator(source::Data.Source, schema::Data.Schema, cols::Vector{Int})

An iterator for tuples from a streaming Data.Source
"""
type StreamTupleIterator{R}
    source::Any
    schema::Data.Schema{R}
    cols::Vector{Int}
end

Base.start(::StreamTupleIterator) = 1
Base.done(iter::StreamTupleIterator, state::Int) = Data.isdone(iter.source, state, 1)
function Base.next(iter::StreamTupleIterator, state::Int)
    t = ntuple(length(iter.cols)) do i
        Data.streamfrom(iter.source, Data.Field, sch.types[iter.cols[i]], state,
                        iter.cols[i]) 
    end
    t, state+1
end

Base.length(iter::StreamTupleIterator{true}) = size(iter.schema, 1)
## TODO: eltype (need to modify type to store eltypes as type parameter)





############################################################################################
# To generate row function: need to know
#
# 1. mapping from symbols to tuple indices
# 2. tuple symbol
# 3. for categorical variables, the unique values/categorical pool for the contrasts matrix
# (stored as a field on the term


"""
    term_ex_factory(term, tup::Symbol, cols::Dict{Symbol,Int}

Create an model matrix row expression from a term expression.

The first return value is an expression that (when evaluated) pulls a value out of a data
row tuple (according to the symbol-index mapping in cols) and returns the corresponding row
for the model matrix.  The second return value is the number of columns created by this
expression.
"""


# two step process: at bottom level, generate code to access a particular term
# value from a tuple.  at top level, handle special formula syntax cases like
# interaction terms and intercepts (integers)

tupleify(x, tup, cols) = x, 1

tupleify(t::ContinuousTerm, tup::Symbol, cols) = :($tup[$(cols[t.name])]), 1

function tupleify(t::CategoricalTerm, tup::Symbol, cols)
    p = CategoricalArrays.CategoricalPool(t.contrasts.levels)
    m = t.contrasts.matrix
    ncols = size(t.contrasts.matrix, 2)
    :($m[get($p, $tup[$(cols[t.name])]), :]), ncols
end

function tupleify(ex::Expr, tup::Symbol, cols)
    is_call(ex) || error("Non-call expression term encountered: $ex")
    children, n_cols = zip([tupleify(c, tup, cols) for c in ex.args[2:end]]...)
    Expr(:call, ex.args[1], children...), 1
end




# default: call tupleify
term_ex_factory(x, tup::Symbol, cols) = tupleify(x, tup, cols)

# special cases at top level:
# integers are parsed as intercept/lack thereof
function term_ex_factory(i::Integer, tup::Symbol, cols)
    if i == 1
        1, 1
    elseif i == 0
        :(), 0
    else
        throw(ArgumentError("invalid term: $i"))
    end
end

function term_ex_factory(ex::Expr, tup::Symbol, cols)
    if is_call(ex, :&)
        children, n_cols = zip([tupleify(c, tup, cols) for c in ex.args[2:end]]...)
        :(kron($(children...))), prod(n_cols)
    elseif is_call(ex, :|)
        # skip ranef terms
    elseif is_call(ex, :+)
        throw(ArgumentError("Call to + encountered. Did you parse!() this expression first? $ex"))
    else
        tupleify(ex, tup, cols)
    end
end

function anon_factory(ex::Union{Expr,Symbol,Int}, col_nums::Dict{Symbol,Int})
    if is_call(ex, :+)
        terms = ex.args[2:end]
    else
        terms = vcat(ex)
    end
    out_sym = gensym("Modelmat row")
    tuple_sym = gensym("Data tuple")
    # a begin ... end block for the body of the anon func
    term_exs = Expr(:block)
    # current starting index
    i = 1
    for term in terms
        term_ex, n_cols = term_ex_factory(term, tuple_sym, col_nums)
        if n_cols > 0
            push!(term_exs.args, :($out_sym[$i:$(i+n_cols-1)] = $term_ex))
        end
        i += n_cols
    end
    :(($out_sym, $tuple_sym) -> $term_exs), i-1
end


function modelmatrix(source, f::Formula)
    parse!(f)
    symbols = vcat(get_symbols(f.lhs), get_symbols(f.rhs))
    sch = Data.schema(source)
    # store the unique values for categorical variables in the schema
    for s in symbols
        if is_categorical(s, sch)
            get_unique!(sch, source, string(s))
        end
    end
    set_schema!(f.rhs, sch)
    
    col_nums = Dict(s=>i for (i,s) in enumerate(symbols))
    fill_row_expr, mm_cols = anon_factory(f.rhs, col_nums)
    fill_row! = eval(fill_row_expr)

    source_col_nums = [sch[string(s)] for s in symbols]
    tuple_iter = zip([StreamColIterator(source, sch, i) for i in source_col_nums]...)

    model_mat = zeros(length(tuple_iter), mm_cols)
    for (i, t) in enumerate(tuple_iter)
        fill_row!(view(model_mat, i, :), t)
    end

    model_mat
end

