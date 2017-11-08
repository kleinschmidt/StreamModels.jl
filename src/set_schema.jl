# TODO: think of a better name for this? and consider using a special container
# type (akin to ModelFrame), since we'd probably like to hold onto the schema,
# too.


################################################################################
# With Formula as a vector of Terms:
#
# entry point is to set_schema on Vector{Term}.  initialize set of terms seen
# already as a Set{Term}.  then map set_schema! on each term.
# 
# for individual Term, default method is to do nothing (return the term), and
# add it to the set of terms already seen.
#
# for dealing with categorical terms, need to keep track of what's been seen so
# far, and the context in which the Term we're currently processing occurred (by
# itself, or as part of an interaction, or otherwise).  All that matters for
# determining whether an aliased term is present is the _set_ of variables
# contained in previously encountered terms, so we also need a way of extracting
# that.

function set_schema!(f::Formula, sch::Data.Schema)
    @argcheck !f.schema_set "Schema already set for this formula!"
    already = Set()
    f.term = set_schema(f.term, Set(), sch)
    f.schema_set = true
    f
end

set_schema(terms::AbstractVector{<:Terms.Term}, already::Set, sch::Data.Schema) =
    map(t->set_schema(t, already, sch), terms)

set_schema(::Void, ::Set, ::Data.Schema) = Void()

set_schema(t::Terms.FormulaTerm, already::Set, sch::Data.Schema) =
    Terms.FormulaTerm(set_schema(t.lhs, Set(), sch),
                      set_schema(t.rhs, already, sch))

set_schema(t::Terms.Intercept, already::Set, ::Data.Schema) = (push!(already, termsyms(t)); t)

set_schema(t::Terms.FunctionTerm, already::Set, ::Data.Schema) =
    (push!(already, termsyms(t)); t)

function set_schema(t::Terms.Interaction, already::Set, sch::Data.Schema)
    new_t = Terms.Interaction(map(s -> set_schema(s, t, already, sch), t.terms))
    push!(already, termsyms(new_t))
    new_t
end

set_schema(t::Terms.Eval, already::Set, sch::Data.Schema) = set_schema(t, t, already, sch)

function set_schema(t::Terms.Eval, context::T, already::Set, sch::Data.Schema) where T<:Terms.Term
    @debug "$t in context of $context, already seen $already"
    push!(already, termsyms(t))
    if is_categorical(t, sch)
        aliased = aliassyms(t, context)
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
        uniq = sch.metadata[:summaries][name(t)][:unique]
        mat = ContrastsMatrix(contr, uniq)
        invindex = Dict(lev => i for (i,lev) in enumerate(mat.levels))
        N = size(mat, 2)
        Terms.Categorical{N}(name(t), mat, invindex)
    else
        Terms.Continuous(name(t))
    end
end

"""
    termsyms(t::Terms.Term)

Extract the Set of symbols referenced in this term.

This is needed in order to determine when a categorical term should have
standard (reduced rank) or full rank contrasts, based on the context it occurs
in and the other terms that have already been encountered.
"""

termsyms(t::Terms.Term) = Set()
termsyms(t::Terms.Intercept) = Set([1])
termsyms(t::Union{Terms.Eval, Terms.Categorical, Terms.Continuous}) = Set([t.name])
termsyms(t::Terms.Interaction) = mapreduce(termsyms, union, t.terms)
termsyms(t::Terms.FunctionTerm) = Set([t.name])


"""
    aliassyms(t::T, context::S) where {T<:Terms.Term, S<:Terms.Term}

Get the Set of symbols that this term potentially aliases in this context.
"""
aliassyms(::Terms.Eval, context::Terms.Eval) = Set([1])
function aliassyms(t::Terms.Eval, context::Terms.Interaction)
    mapreduce(termsyms, union, c for c in context.terms if t ≠ c)
end
