module Terms

import StreamModels.name

using StatsModels: ContrastsMatrix
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

function name(t::Term) end
name(t::Union{Eval, Continuous, Categorical}) = t.name

Base.string(t::Terms.Term) = string(name(t))

"""
    ex_from_formula(x)

As part of the `@formula` macro, take a part of the formula and generate an
expression to construct the appropriate `Term` type.

# Extending the formula language

When `x` is an `Expr(:call, head, args...)`, this function calls the method
`ex_from_formula(Val(head), x)`.  This allows for the formula DSL to be extended
by adding methods for your own operators or functions.  They should return an
`Expr` that constructs a `Term` based on the arguments of the `Expr`.

# Capturing arbitrary functions

For call `Expr`s that don't have specialized methods for `Val{head}`, a 
`FunctionTerm` is generated, which wraps an anonymous function that takes a
single named tuple argument and calls the original function, replacing symbols
in the original `Expr` with fields of the named tuple.
"""
ex_from_formula(i::Integer) = (@argcheck(i==1); :(Terms.Intercept()))
ex_from_formula(s::Symbol) = Expr(:call, :(Terms.Eval), Meta.quot(s))

# calls dispatch on Val{head} for extensibility:
function ex_from_formula(ex::Expr)
    @argcheck is_call(ex)
    ex_from_formula(Val(ex.args[1]), ex)
end


ex_from_formula(::Val{:+}, ex::Expr) =
    Expr(:vect, [ex_from_formula(x) for x in ex.args[2:end]]...)
ex_from_formula(::Val{:&}, ex::Expr) =
    Expr(:call, :(Terms.Interaction),
         Expr(:tuple, [ex_from_formula(x) for x in ex.args[2:end]]...))

# generic: capture calls as anonymous functions of named tuple.  so take
# something like log(1+a) and convert to (tup) -> log(1+tup[:a])
function ex_from_formula(::Val{<:Any}, ex::Expr)
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
