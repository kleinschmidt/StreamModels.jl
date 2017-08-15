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
end

struct Eval <: Term
    name::Symbol
end

# TODO: capture the original expression (and possibly the symbol for the original call)
struct FunctionTerm{F}  <: Term where F<:Function
    f::F
    name::Symbol
end

function name(t::Term) end
name(t::Union{Eval, Continuous, Categorical}) = t.name

Base.string(t::Terms.Term) = string(name(t))

is_call(ex::Expr) = Meta.isexpr(ex, :call)
is_call(ex::Expr, op::Symbol) = Meta.isexpr(ex, :call) && ex.args[1] == op
is_call(::Any) = false
is_call(::Any, ::Any) = false


ex_from_formula(i::Integer) = (@argcheck(i==1); :(Terms.Intercept()))
ex_from_formula(s::Symbol) = Expr(:call, :(Terms.Eval), Meta.quot(s))
function ex_from_formula(ex::Expr)
    @argcheck is_call(ex)
    if is_call(ex, :+)
        Expr(:vect, [ex_from_formula(x) for x in ex.args[2:end]]...)
    elseif is_call(ex, :&)
        Expr(:call, :(Terms.Interaction),
             Expr(:tuple, [ex_from_formula(x) for x in ex.args[2:end]]...))
    else
        # capture calls as anonymous functions of named tuple.  so take
        # something like  log(1+a) and convert to (tup) -> log(1+tup[:a])
        tup_sym = gensym()
        anon_expr = Expr(:(->), tup_sym, replace_symbols!(copy(ex), tup_sym))
        Expr(:call, :(Terms.FunctionTerm), anon_expr, ex.args[1])
    end
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
