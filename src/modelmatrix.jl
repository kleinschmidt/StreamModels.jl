"""
    nc(t::Type{T}) where T <: Terms.Term

Return the number of columns generated by a term of type `t`.  For `Continuous`,
`Intercept`, and `FunctionTerm`, this is 1.  For `Categorical`, it's the size of
the contrasts matrix.  For an `Interaction` term, it's the product of the number
of columns generated by the children terms.  For an `Eval` term, an error is
thrown (since it can't be determined).

For a custom term type, you need to provide an `nc` method as well as a
`rowval` method.


"""
nc(t::Type{Terms.Eval}) =
    throw(ArgumentError("can't compute number of columns generated by un-typed " *
                        "Eval term $t. Did you forget to `set_schema`?"))
nc(::Type{Terms.Term}) = 0
nc(::Type{Terms.Intercept}) = 1
nc(::Type{Terms.Continuous}) = 1
nc(::Type{Terms.Categorical{N}}) where N = N
nc(::Type{Terms.Interaction{T}}) where T = mapreduce(nc, *, T.parameters)
# TODO: is this right? should we handle n-ary functions?
nc(::Type{Terms.FunctionTerm{F1,F2}}) where {F1,F2} = 1 

"""
    (term::<:Terms.Term)(data::NamedTuple)

Calling a term with a named tuple should realize the data corresponding to that
named tuple as a numeric vector

"""
(::Terms.Intercept)(data::NamedTuple) = 1
(t::Terms.Continuous)(data::NamedTuple) = data[t.name]
(t::Terms.Categorical)(data::NamedTuple) =
    t.contrasts.matrix[t.invindex[data[t.name]], :]
(t::Terms.FunctionTerm)(data::NamedTuple) = t.f(data)
# TODO: does this really need to be @generated??
@generated function (t::Terms.Interaction)(data::NamedTuple)
    nterms = length(t.parameters[1].parameters)
    Expr(:call, :kron, [:(t.terms[$ti](data)) for ti in 1:nterms]...)
end

# TODO: add methods for named tuple of vectors (e.g. Data.Table): I think it's
# just the interaction and function terms that need special cases for this.


################################################################################
# Now we have a Formula with a vector of Terms that are typed.  We just need to
# have a generated function that generates the code for filling in a single
# model matrix row (similar to what AnonFactory does).  This requires knowing
# the number of columns generated by each term (`nc`).

function modelmatrix(source, f::Formula)
    f.schema_set || set_schema!(f, summarize(source, f))
    modelmatrix(source, tuple(f.term.rhs...))
end

function modelmatrix(source, terms::T) where T<:Tuple{Vararg{Terms.Term,N}} where N
    iter = RowIterator(source)
    
    nrows = length(iter)

    @debug T.parameters
    ncols = mapreduce(nc, +, T.parameters)
    mat = Array{Float64}(nrows, ncols)

    for (i, data) in enumerate(iter)
        modelmatrow!(view(mat, i, :), data, terms)
    end

    mat
end


"""
    modelmatrow!(row::AbstractVector, data::NamedTuple, terms::Tuple)
    modelmatrow(data::NamedTuple, terms::Tuple)

Fill one model matrix row based on a data named tuple and terms.

"""
@generated function modelmatrow!(row::AbstractVector, data::NamedTuple, terms::Tuple)
    Ts = collect(terms.parameters)
    ncols = mapreduce(nc, +, Ts)
    @debug "$ncols columns"
    @debug "Terms:"
    for T in Ts
        @debug T
    end

    func_body = Expr(:block)
    ci = 0
    for ti in eachindex(Ts)
        starti, ci = ci+1, ci+nc(Ts[ti])
        push!(func_body.args, :(@inbounds row[$starti:$ci] = terms[$ti](data)))
    end
    push!(func_body.args, :(row))
    @debug func_body
    return func_body
end

@generated function modelmatrow(data::NamedTuple, terms::Tuple)
    Ts = collect(terms.parameters)
    cols = mapreduce(nc, +, Ts)
    :(modelmatrow!(Array{Float64}($cols), data, terms))
end
