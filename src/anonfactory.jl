############################################################################################
# To generate row function: need to know
#
# 1. mapping from symbols to tuple indices
# 2. tuple symbol
# 3. for categorical variables, the unique values/categorical pool for the contrasts matrix
# (stored as a field on the term



type AnonFactory
    # generated symbol for the output
    out_sym::Symbol
    # generated symbol for the input tuple
    tuple_sym::Symbol
    # map term symbols to tuple column nums
    tuple_invindex::Dict{Symbol,Int}
    # map contrasts matrices to symbols for the categorical pool and the matrix
    # (in order to generate the let block)
    contrasts::Dict{ContrastsMatrix,Tuple{Symbol,Symbol}}
    # number of columns that will be generated
    num_cols::Int
    # expressions for each term
    term_exprs::Vector{Expr}
    # expressions for the start of the let block
    let_exprs::Vector{Expr}
end

function AnonFactory(ex::Union{Expr,Term,Int}, col_nums::Dict{Symbol,Int})
    if is_call(ex, :+)
        terms = ex.args[2:end]
    else
        terms = vcat(ex)
    end
    out_sym = gensym("Modelmat row")
    tuple_sym = gensym("Data tuple")
    
    af = AnonFactory(out_sym, tuple_sym, col_nums,
                     Dict{ContrastsMatrix,Tuple{Symbol,Symbol}}(), 0,
                     Expr[], Expr[])

    map(t -> add_term!(af, t), terms)
    af
end

model_function_exp(af::AnonFactory) =
    quote
        let $(af.let_exprs...)
            ($(af.out_sym), $(af.tuple_sym)) -> begin
                $(af.term_exprs...)
            end
        end
    end

Base.convert(::Type{Function}, af::AnonFactory) = eval(model_function_exp(af))

"""
    out_expr(af::AnonFactory, idx)

Generate an expression to index the output vector from the `AnonFactory` at
index/indices `idx`.
"""
out_expr(af::AnonFactory, idx) = :($(af.out_sym)[$idx])

"""
    in_expr(af::AnonFactory, col)

Generate an expression to access column `col` in the input tuple from an
`AnonFactory`
"""
in_expr(af::AnonFactory, col) = :($(af.tuple_sym)[$(af.tuple_invindex[col])])
# TODO: deal with nullables here

"""
    term_ex(t, af::AnonFactory)

Generate an expression from a term based on an `AnonFactory`.  Continuous and
Categorical Terms are turned into expressions that access values in the
functions input data tuple.  For Categorical terms, this is done using generated
symbols to refer to the cateogrical pool and contrasts matrix that will be
placed in a let block around the function body.  Expressions are converted
recursively (to support custom functions in the formula).

"""

function term_ex end

# default is a no-op (for e.g., numbers or other arguments in custom functions)
term_ex(t, af::AnonFactory) = t

term_ex(t::ContinuousTerm, af::AnonFactory) = in_expr(af, t.name)
function term_ex(t::CategoricalTerm, af::AnonFactory)
    mat_sym, pool_sym = get!(af.contrasts, t.contrasts) do
        # if this ContrastsMatrix is new to us, create symbols for the matrix
        # and pool and add these to the let expressions vector
        mat_sym = gensym("ContrMat $(t.name)")
        pool_sym = gensym("CatPool $(t.name)")
        push!(af.let_exprs, :($mat_sym = $(t.contrasts.matrix)))
        push!(af.let_exprs, :($pool_sym = $(CategoricalPool(t.contrasts.levels))))
        (mat_sym, pool_sym)
    end
    :($mat_sym[get($pool_sym, $(in_expr(af, t.name))), :])
end

# recursively expand expressions (will bottom out at Continuous/CategricalTerms
function term_ex(t::Expr, af::AnonFactory)
    @argcheck is_call(t) ArgumentError("Non-call expression term encountered: $t")
    Expr(:call, t.args[1], [term_ex(tt, af) for tt in t.args[2:end]]...)
end

nc(t) = 1
nc(t::CategoricalTerm) = size(t.contrasts.matrix, 2)

"""
    add_term!(af::AnonFactory, term)

Generate an expression to write one term's model matrix entries into an output
row, and insert that expression into the list of term expressions in `af`.
"""
function add_term! end

function add_term!(af::AnonFactory, term)
    start, fin = af.num_cols+1, (af.num_cols += nc(term))
    start <= fin || return
    out_ex = start == fin ? out_expr(af, start) : out_expr(af, start:fin)
    push!(af.term_exprs, :($out_ex = $(term_ex(term, af))))
end

function add_term!(af::AnonFactory, term::Integer)
    @argcheck term ∈ [0,1] ArgumentError("invalid term: $term (only 0 and 1 allowed)")
    af.num_cols += 1
    push!(af.term_exprs, :($(out_expr(af, af.num_cols)) = 1))
end

function add_term!(af::AnonFactory, term::Expr)
    @argcheck !is_call(term, :+) ArgumentError("Call to + encountered. Did you parse!() this expression first? $term")
    if is_call(term, :&)
        ncols = prod(nc(t) for t in term.args[2:end])
        out_ex = out_expr(af, (af.num_cols + 1):(af.num_cols += ncols))
        term_exprs = [term_ex(t, af) for t in term.args[2:end]]
        push!(af.term_exprs, :($out_ex = kron($(term_exprs...))))
    elseif is_call(term, :|)
        # skip ranef terms
    else
        out_ex = out_expr(af, (af.num_cols + 1):(af.num_cols += nc(term)))
        push!(af.term_exprs, :($out_ex = $(term_ex(term, af))))
    end
end
