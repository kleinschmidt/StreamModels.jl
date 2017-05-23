################################################################################
# set_schema! when you just have an Expr:
#
# for each Symbol (eval term), need to check whether variable is continuous or
# categorical, and save contrasts information for categorical variables.
#
# to determine contrasts, need to know what aliases what.
#
# first thought was that to save contrasts you'd just need to replace symbols
# that correspond to a categorical variable with an expression like,
# :(contr($sym,DummyCoding)).
#
# wait, that's fine.  because when you construct the actual ContrastsMatrix, you
# need to pass the actual levels anyway.  then the question is where you put the
# ContrastsMatrix...it can't just go into the anonymous function because you
# need the contrasts to be able to interpret the results of a model...
#
# maybe will help to think about the whole lifecycle of a formula.
# 1. starts as two Exprs, left and right side
# 2. rhs gets parsed into expanded form: *, distributive + assoc properties.
# 3. given data (schema), set contrasts for categorical variables (checking for
#    redundancy/aliasing)
# 4. given data, generate a model matrix
# 5. give coefficient names for fitted model
#
# In the current scheme, 2 happens at Terms() (re-writing the Expr first), 3 at
# ModelFrame(), and 4 at ModelMatrix.  Contrasts are stored on the model frame.
#
# In the Term{H} scheme, 2 is handled by converting to a tree of Term{}s, 3 by
# re-writing EvalTerm nodes in that tree based on the data, and 4 either by
# generating columns or by generating rows from tuples.
#
# In the raw Expr scheme, 2 is handled by re-writing the Expr, 3 by replacing
# Symbol nodes with categorical variables with ... something? Something that's a
# call users could use to indicate that they want contrasts.  Analogous to R's
# C().  Could use :( contr($var, $contrasts) ).  Then eval($contrasts) to get
# the contrasts, construct a ContrastsMatrix, and replace the Expr with the
# actual contrasts matrix.  Then generate code based on that to get right row of
# matrix for one element at a time.
#
# ALternatively, a hybrid scheme: replace Symbols with value types when combined
# with data schema.  That allows for the best of both worlds, with the possible
# complication of special-casing calls to contr() in the Expr.



# To set schema based on a DataStreams.Data.Source:
#
# 1. get symbol nodes from expression
# 2. get eltypes for each unique one
# 3. For categorical types, get unique values (iterate over data) and add to
#    schema.
# 4. crawl Expr, converting symbol nodes to Continuous/CategoricalTerm objects
#    checking for redundancy as necessary
# 5. hold onto terms-ified expression, schema, and source

get_symbols(s::Symbol) = s
get_symbols(x) = []
function get_symbols(ex::Expr)
    check_call(ex)
    unique(mapreduce(get_symbols, vcat, Symbol[], ex.args[2:end]))
end


is_categorical(s, sch::Data.Schema) = is_categorical(string(s), sch)
is_categorical(s::String, sch::Data.Schema) = is_categorical(Data.types(sch)[sch[s]])
is_categorical{T<:Real}(::Type{T}) = false
is_categorical{T<:Real}(::Type{Nullable{T}}) = false
is_categorical(::Type) = true


Base.string{T}(io::IO, t::ContinuousTerm{T}) = "$(t.name)($T)"
Base.string{T,C}(io::IO, t::CategoricalTerm{T,C}) = "$(t.name)($C{$T})"

Base.show{T}(io::IO, t::ContinuousTerm{T}) = print(io, "$(t.name)($T)")
Base.show{T,C}(io::IO, t::CategoricalTerm{T,C}) = print(io, "$(t.name)($(C){$(T)})")


# set schema for data, checking redundancy as we go in order to promote
# categorical contrasts where necessary.
#
# strategy for checking redundancy is to keep track of terms that we've already
# seen, and checking for whether the term aliased is present

is_call(ex::Expr) = Meta.isexpr(ex, :call)
is_call(ex::Expr, op::Symbol) = Meta.isexpr(ex, :call) && ex.args[1] == op
is_call(::Any) = false
is_call(::Any, ::Any) = false

extract_singleton(s::Set) = length(s) == 1 ? first(s) : s

# in the context of an interaction term, a term aliases the version of that
# interaction where it's been removed.  in the context of a _non_-interaction
# expr (call to an aribtrary function), nothing is aliased
function alias(s, context::Expr)
    if is_call(context, :&)
        extract_singleton(Set(c for c in context.args[2:end] if c ≠ s))
    end
end

# in the context of itself, a single term aliases the intercept
alias(s, t::Symbol) = s == t ? 1 : nothing

_unique(col, sch::Data.Schema) = sch.metadata[:unique][string(col)]

set_schema!(i::Integer, already::Set, sch::Data.Schema) = (push!(already, i); i)

set_schema!(s::Symbol, already::Set, sch::Data.Schema) = set_schema!(s, s, already, sch)

_eltype(s, sch::Data.Schema) = Data.types(sch)[sch[string(s)]]

# convert a symbol into either a ContinuousTerm or CategoricalTerm (with the
# appropriate contrasts, given the context this symbol appears in and the
# lower-order terms that have already been encountered).
function set_schema!(s::Symbol, context, already::Set, sch::Data.Schema)
    @debug "$s in context of $context, already seen $already"
    push!(already, s)
    if is_categorical(s, sch)
        aliased = alias(s, context)
        @debug "  aliases: $aliased"
        if aliased in already
            # TODO: allow custom contrasts here
            contr = DEFAULT_CONTRASTS()
        else
            # lower-order term that is aliased by full-rank contrasts for this
            # term is NOT present, so use full-rank contrasts and add the
            # aliased term to the set of terms we've seen
            contr = FullDummyCoding()
            push!(already, aliased)
        end
        CategoricalTerm(s, ContrastsMatrix(contr, _unique(s, sch)))
    else
        ContinuousTerm{_eltype(s, sch)}(s)
    end
end

function set_schema!(ex::Expr, already::Set, sch::Data.Schema)
    if is_call(ex, :&)
        push!(already, Set(ex.args[2:end]))
        ex.args[2:end] = map(c -> set_schema!(c, ex, already, sch), ex.args[2:end])
    elseif is_call(ex, :|)
        # random effect terms need to be handled differently...just skip for now
    elseif is_call(ex, :contr)
        # place holder for specifying contrasts within formula
    else
        # general case: set schema on all children
        ex.args[2:end] = map(c -> set_schema!(c, already, sch), ex.args[2:end])
    end
    ex
end

set_schema!(x, sch::Data.Schema) = set_schema!(x, Set(), sch)

