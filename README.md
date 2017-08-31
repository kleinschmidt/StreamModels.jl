**NOTE: This currently relies on the NamedTuples PR to Base
[JuliaLang/julia#22194](https://github.com/JuliaLang/julia/pull/22194)**  It
could in principle be made to work with
[NamedTuples.jl](https://github.com/blackrock/NamedTuples.jl) but I'm lazy.

# StreamModels

[![Build Status](https://travis-ci.org/kleinschmidt/StreamModels.jl.svg?branch=master)](https://travis-ci.org/kleinschmidt/StreamModels.jl)
[![codecov.io](http://codecov.io/github/kleinschmidt/StreamModels.jl/coverage.svg?branch=master)](http://codecov.io/github/kleinschmidt/StreamModels.jl?branch=master)

This is a prototype of a different approach to generating numerical model
matrices based on tabular data and a formula.  It works with any data source
that produces a `Data.Schema` and an row iterator of `NamedTuple`s.  In
principle, that's anything that satisfies the [DataStreams `Data.Source`
interface](http://juliadata.github.io/DataStreams.jl/stable/), including
in-memory stores like DataFrames/DataTables, as well as databases and files on
disk like CSV and Feather.  But at the moment it's restricted to an in-memory
store (a `Data.Table`, which is just a `NamedTuple` of `AbstractVector`
columns).

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
