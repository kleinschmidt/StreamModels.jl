type Formula
    lhs::Union{Symbol, Expr, Void}
    rhs::Union{Symbol, Expr, Integer}
end

macro formula(ex)
    raise_tilde!(ex)
    if (ex.head === :macrocall && ex.args[1] === Symbol("@~")) || (ex.head === :call && ex.args[1] === :(~))
        2 <= length(ex.args) <= 3 || error("malformed formula: $ex")
        lhs = length(ex.args) == 3 ? Base.Meta.quot(ex.args[2]) : nothing
        rhs = Base.Meta.quot(ex.args[end])
    else
        error("expected formula separator ~, got $(ex.head)")
    end
    return Expr(:call, :Formula, lhs, rhs)
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
    if Meta.isexpr(ex, :call) && Meta.isexpr(ex.args[2], :call) && ex.args[2].args[1] === :~
        length(ex.args[2].args) == 2 || throw(ArgumentError("malformed formula: $ex"))
        ex.args[2] = ex.args[2].args[2]
        ex.args = [:~, deepcopy(ex)]
    end
    ex
end

Base.:(==)(f1::Formula, f2::Formula) = all(getfield(f1, f)==getfield(f2, f) for f in fieldnames(f1))




check_call(ex) = Meta.isexpr(ex, :call) || throw(ArgumentError("non-call expression encountered: $ex"))

const DEBUG = true

macro debug(msg)
    DEBUG ? :(println(string($(esc(msg))))) : nothing
end

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
degree(s::Symbol) = 1
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
