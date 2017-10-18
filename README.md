
# StreamModels

[![Build Status](https://travis-ci.org/kleinschmidt/StreamModels.jl.svg?branch=master)](https://travis-ci.org/kleinschmidt/StreamModels.jl)
[![codecov.io](http://codecov.io/github/kleinschmidt/StreamModels.jl/coverage.svg?branch=master)](http://codecov.io/github/kleinschmidt/StreamModels.jl?branch=master)

## The idea

This is a prototype of a different approach to generating numerical model
matrices based on tabular data and a formula.  It works with any data source
that produces a `Data.Schema` and an row iterator of `NamedTuple`s.  In
principle, that's anything that satisfies the [DataStreams `Data.Source`
interface](http://juliadata.github.io/DataStreams.jl/stable/), including
in-memory stores like DataFrames/DataTables, as well as databases and files on
disk like CSV and Feather.  

## Current status

At the moment this is a proof of concept/sandbox for prototyping ideas.

* Restricted to an in-memory store (a `Data.Table`, which is just a `NamedTuple`
  of `AbstractVector` columns).
* **It relies on the NamedTuples PR to Base
  [JuliaLang/julia#22194](https://github.com/JuliaLang/julia/pull/22194)**.  It
  could in principle be made to work with
  [NamedTuples.jl](https://github.com/blackrock/NamedTuples.jl) but I'm lazy.

## Strategy

The strategy deviates substantially from the original implementation (in
`StatsModels.jl`).  The reason for this is that the original implementation is
based on how R does this, and R mixes metaprogramming and normal execution of
code more freely than Julia does.  This makes it tricky to implement some of the
features that we want in a formula domain specific language:

1. Concise domain-specific expressions for interactions (e.g., `a*b` means main
   effects for `a` and `b`, and a term for the `a&b` interaction), random
   effects (`(1+a | subject)` means random intercept and slope for `a` for each
   subject), etc.  That is, some symbols have different interpretations than in
   base julia.
2. The interpretation of symbols referring to variables depends on their types
   (e.g. continuous vs. categorical), and for some symbols on their _values_
   (e.g., the levels of a categorical variable).
3. Calls that _don't_ have special DSL interpretations should be treated as
   normal Julia code (e.g., if you want to lazily log-transform a predictor with
   `log(a)`).

In order to generate a model matrix from streaming data, we'd ideally like a
fast, specialized inner loop that generates one row a time.  But we can't do
code generate with just a macro, because the results depend on run time
information (whether a variable is categorical or not, etc.).  So we need a
three-stage approach:

1. Parse formula expression into a lowered form, and create `Term`s
   representations for each term.  This includes turning function calls that
   don't have a special formula DSL interpretation into anonymous functions that
   consume a single row of data.  Terms that need run time information are
   converted into `Eval` terms.
2. Consume the data source once to determine the types and any necessary
   invariants of the data to realize `Eval` terms (unique elements for
   categorical variables), and convert `Eval` terms into concrete `Continuous`
   or `Categorical` terms.  For categorical variables, contrasts matrices are
   computed and stored on the term.
3. A generated function that creates one row at a time based on the tuple of
   terms and a `NamedTuple` of data for one row.  The loop over terms can be
   unrolled since each term type is annotated with the number of columns that it
   will generate.

## Planned API

My long-term hope is that this is a second-generation version of StatsModels
with a more general and extensible API, including both streaming data, generic
tabular data, and "multipart formulas" (as discussed
[here](https://github.com/JuliaStats/StatsModels.jl/issues/21)).  The high-level
entry point will be the `@model` macro, which captures formulas in a model
constructor arguments and creates a `ModelBuilder` struct which is parametrized
by the type of model constructed:

```julia
julia> @model df GLM(y ~ 1 + x*condition, family=Binomial)

ModelBuilder{GLM}:
    data:
        df
    args:
        Formula(y~1+x+condition+x&conditino),
    kw args:
        family=Binomial
```

This type will have a default in this package that immediately applies the data
to the formulae and calls the model constructor with the resulting numerical
matrices/vectors replacing the corresponding formulae.  The result will be
stored in a `ModelFrame{M}` struct, parametrized by the model type.

Packages that want to do non-traditional things with the formulae (like using
nested formulae to denote the relationship between endogenous and instrumental
variables in
[FixedEffectsModels.jl](https://github.com/matthieugomez/FixedEffectModels.jl))
can add `ModelBuilder{M}` constructor methods for their own model types,
allowing them to manipulate the extracted formulae as necessary.

## Extending

This package is designed to make the formula DSL extendable if you need to add
special syntax or terms.  Essentially any julia operator or function can be
given special meaning.  The points to extend are:

* A subtype of `Terms.Term` to represent your special terms.
* Method(s) for evaluating your term given a row of data:
  `(t::MyTerm)(data::NamedTuple)`.  This should return a numeric vector
* A method of `Terms.ex_from_formula` to convert the abbreviated formula syntax
  into a constructor for your term type.  `Terms.ex_from_formula(::Val{head},
  ex::Expr)` where `head` is the symbol that is the head of a call `ex`.  For
  instance, if you wanted to add support for random effects of the form 
  `(1+x | subject)`, you'd need to add a method `ex_from_formula(::Val{:|}, ex::Expr)`
  that would return something like `:(ReTerm($(ex.args[2]), $(ex.args[3])))` (in
  actual fact you'd probably need to parse the sub-expressions as well,
  constructing the necessary terms for them)
* A method `nc(::Type{MyTerm})` to determine the number of columns that your
  term will generate **based only on the type**.
