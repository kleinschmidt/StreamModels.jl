# TODO: extensibility of parsing and Terms types.  Allow for ranef terms etc.
# Use dispatch in `term_ex_from_formula_ex`

mutable struct Formula
    ex::Expr
    ex_lowered::Expr
    term::Terms.FormulaTerm
    schema_set::Bool
end


Base.copy(f::Formula) = Formula(copy(f.lhs), copy(f.rhs))

function _formula!(ex::Expr)
    raise_tilde!(ex)
    @argcheck is_call(ex, :~) "expected formula separator ~, got $(ex.head)"
    @argcheck 2 <= length(ex.args) <= 3 "malformed formula: $ex"

    ex_orig = copy(ex)
    if length(ex.args) == 2
        ex.args = [ex.args[1], nothing, ex.args[2]]
    end
    ex.args[3] = sort_terms!(parse!(Expr(:call, :+, ex.args[3])))

    term_ex = Terms.term_ex_from_formula_ex(ex)
    return Expr(:call, :Formula, Meta.quot(ex_orig), Meta.quot(ex), term_ex, false)
end

macro formula(ex)
    _formula!(ex)
end

function Base.show(io::IO, f::Formula)
    print(io, "formula: ")
    lhs, rhs = f.ex_lowered.args[2:3]
    lhs === nothing || print(io, "$lhs ")
    print(io, "~ $rhs")
end

"""
    raise_tilde!(ex::Expr)

"Correct" the parser's handling of non-infix ~ in order to support one-sided
formulas.  The parser treats it as a unary operator, so the tilde call ends
up as the first argument of the central expression.

That is, the one-sided formula ~1+a parses as :(~(1)+a), which needs to be
converted to :(~(1+a)).

"""
function raise_tilde!(ex::Expr)
    if is_call(ex) && is_call(ex.args[2], :~)
        length(ex.args[2].args) == 2 || throw(ArgumentError("malformed formula: $ex"))
        ex.args[2] = ex.args[2].args[2]
        ex.args = [:~, deepcopy(ex)]
    end
    ex
end

Base.:(==)(f1::Formula, f2::Formula) = all(getfield(f1, f)==getfield(f2, f) for f in fieldnames(f1))




check_call(ex) = Meta.isexpr(ex, :call) || throw(ArgumentError("non-call expression encountered: $ex"))

# expression re-write rules:
expand_star(a, b) = Expr(:call, :+, a, b, Expr(:call, :&, a, b))
function expand_star!(ex::Expr)
    @debug "  expand star: $ex -> "
    ex.args = reduce(expand_star, ex.args[2:end]).args
    @debug "               $ex"
    ex
end

const ASSOCIATIVE = Set([:+, :&, :*])
associative(a, b) =
    Meta.isexpr(a, :call) &&
    Meta.isexpr(b, :call) &&
    a.args[1] in ASSOCIATIVE &&
    a.args[1] == b.args[1]

function associate!(ex::Expr, child_idx::Integer)
    @debug "    associative: $ex -> "
    splice!(ex.args, child_idx, ex.args[child_idx].args[2:end])
    @debug "                 $ex"
    child_idx
end

# Distributive property
# &(a..., +(b...), c...) -> +(&(a..., b_i, c...)_i...)
#
# replace outer call (:&) with inner call (:+), whose arguments are copies of
# the outer call, one for each argument of the inner call.  For the ith new
# child, the original inner call is replaced with the ith argument of the inner
# call.
const DISTRIBUTIVE = Set([:& => :+])
distributive(a, b) =
    Meta.isexpr(a, :call) &&
    Meta.isexpr(b, :call) &&
    (a.args[1] => b.args[1]) in DISTRIBUTIVE

function distribute!(ex::Expr, child_idx::Integer)
    @debug "    distributive: $ex -> "
    new_args = deepcopy(ex.args[child_idx].args)
    for i in 2:length(new_args)
        new_child = deepcopy(ex)
        new_child.args[child_idx] = new_args[i]
        new_args[i] = new_child
    end
    ex.args = new_args
    @debug "                  $ex"
    2
end

parse!(s::Symbol) = s
parse!(i::Integer) = i ∈ [-1, 0, 1] ? i :
    throw(ArgumentError("invalid integer term $i (only -1, 0, and 1 allowed)"))

## TODO: re-write this in terms of generic re-write rules to make more extensible
## the rules have a form like
## 1. check if rule applies, given ex and (idx of) child being parsed.
## 2. re-write expression starting from idx of child.
## 3. return idx of next child to check.
##
## might need to differentiate between pre-walk and post-walk rules?  or change
## where the star expansion happens (should be able to check it...)
function parse!(ex::Expr)
    @debug "parsing $ex"
    check_call(ex)
    if ex.args[1] == :*
        expand_star!(ex)
    end
    # iterate over children, checking for special rules
    child_idx = 2
    while child_idx <= length(ex.args)
        @debug "  ($(ex.args[1])) i=$child_idx: $(ex.args[child_idx])"
        # depth first: parse each child first
        parse!(ex.args[child_idx])
        if associative(ex, ex.args[child_idx])
            child_idx = associate!(ex, child_idx)
        elseif distributive(ex, ex.args[child_idx])
            child_idx = distribute!(ex, child_idx)
        else
            # no special rules apply, move onto next
            child_idx += 1
        end
    end
    @debug "done: $ex"
    ex
end

parse!(x) = x
Base.copy(x::Void) = x
Base.copy(x::Symbol) = x

function sort_terms!(ex::Expr)
    check_call(ex)
    if ex.args[1] ∈ ASSOCIATIVE
        sort!(view(ex.args, 2:length(ex.args)), by=degree)
    elseif ex.args[1] == :|
        # sort mini terms inside ranef term
        sort_terms!(ex.args[2])
    end
    ex
end
sort_terms!(x) = x

degree(i::Integer) = 0
degree(::Symbol) = 1
# degree(s::Union{Symbol, ContinuousTerm, CategoricalTerm}) = 1
function degree(ex::Expr)
    check_call(ex)
    if ex.args[1] == :&
        length(ex.args) - 1
    elseif ex.args[1] == :|
        # put ranef terms at end
        Inf
    else
        # arbitrary functions are treated as main effect terms
        1
    end
end
