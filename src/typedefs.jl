# How many types do we need?  Original StatsModels has three/four:
# Formula/Terms, ModelFrame, and ModelMatrix.  In this formulation, the Formula
# is basically just an expression, headed by :~.  Combined with a Data.Schema,
# you get a transformed expression that you can use to generate a model matrix
# when combined with a data source.

@compat abstract type Term end

type ContinuousTerm{T} <: Term
    name::Symbol
end

type CategoricalTerm{T,C} <: Term
    name::Symbol
    contrasts::ContrastsMatrix{C,T}
end

type Formula
    lhs::Union{Symbol, Expr, Term, Void}
    rhs::Union{Symbol, Expr, Term, Integer}
end

