module Terms

using ..is_call
using ..ContrastsMatrix

import StreamModels.name

using ArgCheck

abstract type Term end

struct Intercept <: Term end

struct Interaction{Ts} <: Term
    terms::Ts
end

struct Continuous <: Term
    name::Symbol
end

struct Categorical{N} <: Term
    name::Symbol
    contrasts::ContrastsMatrix
    invindex::Dict
end

struct Eval <: Term
    name::Symbol
end

# TODO: capture the original expression (and possibly the symbol for the original call)
struct FunctionTerm{F,Forig}  <: Term where {F <: Function, Forig <: Function}
    f::F
    forig::Forig
    name::Expr
end

struct FormulaTerm{L,R}
    lhs::L
    rhs::R
end

"""
    haslhs(ft::FormulaTerm{L})

Return true is the LHS type is not Void
"""
haslhs(ft::FormulaTerm{L}) where L = L!==Void


function name(t::Term) end
name(t::Union{Eval, Continuous, Categorical}) = t.name

Base.string(t::Terms.Term) = string(name(t))

"""
    ismatrixterm(T::Type{<:Term})
    ismatrixterm(t::T) where T<:Term

Return true if this type should be included in a single model matrix (e.g., a
random effect term should return false).
"""
ismatrixterm(::T) where T<:Term = false

for T in [FunctionTerm, Categorical, Continuous, Intercept, Interaction]
    @eval ismatrixterm(::S) where S<:$T = true
end


"""
    flatten_formula(term::FormulaTerm)

Extract a vector of "flattened" terms.  If present, the first element will be
the LHS.  The next will be a vector of all the "matrix terms", and any other
terms will be passed through unchanged

"""
function flatten_formula(term::FormulaTerm)
    # create a tuple of terms where we:
    # 1. pull out LHS is present
    # 2. collect LHS matrix terms
    # 3. pass the rest on alone
    new_terms = []
    matrix_terms = []
    for t in term.rhs
        if ismatrixterm(t)
            push!(matrix_terms, t)
        else
            push!(new_terms, t)
        end
    end
    !isempty(matrix_terms) && unshift!(new_terms, tuple(matrix_terms...))
    haslhs(term) && unshift!(new_terms, term.lhs)
    tuple(new_terms...)
end


"""
    term_ex_from_formula_ex(x)

As part of the `@formula` macro, take a part of the formula and generate an
expression to construct the appropriate `Term` type.

# Extending the formula language

When `x` is an `Expr(:call, head, args...)`, this function calls the method
`term_ex_from_formula_ex(Val(head), x)`.  This allows for the formula DSL to be extended
by adding methods for your own operators or functions.  They should return an
`Expr` that constructs a `Term` based on the arguments of the `Expr`.

# Capturing arbitrary functions

For call `Expr`s that don't have specialized methods for `Val{head}`, a 
`FunctionTerm` is generated, which wraps an anonymous function that takes a
single named tuple argument and calls the original function, replacing symbols
in the original `Expr` with fields of the named tuple.
"""
term_ex_from_formula_ex(::Void) = nothing
term_ex_from_formula_ex(i::Integer) = (@argcheck(i==1); :(Terms.Intercept()))
term_ex_from_formula_ex(s::Symbol) = Expr(:call, :(Terms.Eval), Meta.quot(s))

# calls dispatch on Val{head} for extensibility:
function term_ex_from_formula_ex(ex::Expr)
    @argcheck is_call(ex)
    term_ex_from_formula_ex(Val(ex.args[1]), ex)
end

term_ex_from_formula_ex(::Val{:~}, ex::Expr) =
    Expr(:call, :(Terms.FormulaTerm),
         term_ex_from_formula_ex(ex.args[2]),
         term_ex_from_formula_ex(ex.args[3]))
term_ex_from_formula_ex(::Val{:+}, ex::Expr) =
    Expr(:vect, [term_ex_from_formula_ex(x) for x in ex.args[2:end]]...)
term_ex_from_formula_ex(::Val{:&}, ex::Expr) =
    Expr(:call, :(Terms.Interaction),
         Expr(:tuple, [term_ex_from_formula_ex(x) for x in ex.args[2:end]]...))

# generic: capture calls as anonymous functions of named tuple.  so take
# something like log(1+a) and convert to (tup) -> log(1+tup[:a])
function term_ex_from_formula_ex(::Val{<:Any}, ex::Expr)
    tup_sym = gensym()
    anon_expr = Expr(:(->), tup_sym, replace_symbols!(copy(ex), tup_sym))
    f_orig = ex.args[1]
    Expr(:call, :(Terms.FunctionTerm), anon_expr, f_orig, Meta.quot(ex))
end    

replace_symbols!(x, tup::Symbol) = x
replace_symbols!(x::Symbol, tup::Symbol) = Expr(:ref, tup, Meta.quot(x))
function replace_symbols!(ex::Expr, tup::Symbol)
    if is_call(ex)
        ex.args[2:end] .= [replace_symbols!(x, tup) for x in ex.args[2:end]]
    end
    ex
end

end # module Terms
