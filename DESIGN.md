# Design of `StreamModels.jl`

In order to efficiently ingest streaming data, we need a way to parse and
transform one named tuple at a time into a numeric vector with as little
overhead as possible.  Most of the transformations are simple (copying numeric
values over, converted to the element type of the output) but we want to support
arbitrary julia code in the formula notation (within limits).

This package uses a two-stage approach: a macro stage where only the expression
of the formula is known, and a runtime stage where the types and some
information about the values is known.  This is necessary because it's not
possible to fully specify a custom anonymous function to ingest an entire rows
worth of data without knowing something about _values_ contained in the data
(like the number of levels of a categorical variable), but we still want to
compile specialized code and so don't want to do it all at runtime.  First, the
`@formula` macro parses the formula expression into a vector of terms, lowering
the formula notation to a more explicit form and creating anonymous functions
where necessary for non-formula-specific notation.  Then at runtime, the data
source is checked for the types and (for categorical data) the values of the
data in order to determine the alignment of terms and model matrix columns.
Finally, this information is passed (along with each tuple) to a `@generated
function` which creates specialized code to access, transform, and write the
data into the model matrix.

# Motivation

A bottleneck in the previous implementation is in looping over the terms, right?
We do that loop once per model matrix call in the original but it would have to
happen _every_ row when you only get one row at a time.  So the point of using
the generated function is to unroll that loop.

I think we can get a lot of the way there by making the term types callable (and
take a named tuple as an argument).  Then you can have a "function terms" that
calls some code.  We create _thsoe_ during the formula parsing, and update them
when we have data available.  This would also allow you to specialize on the
particular function!

So we have 

* `ContinuousTerm`: just pull out value from tuple
* `CategoricalTerm{N}`: pull out value from tuple and get vector from contrasts
  matrix.
* `InteractionTerm{Children}`: call `kron` on the child terms.
* `FunctionTerm{F}`: call a function on values pulled out of the tuple.
* `DeferredTerm`? For converting the formula to a vector of terms before data is
  available. A place holder with just the name.
* `InterceptTerm`

# `@formula`

1. Parse and lower formula.
2. Create terms (using `DeferredTerm` where leaf symbols are encountered and
   generating anonymous functions for function terms).

# Combine with data

1. Eval deferred terms based on data schema.  This might require updating the
   schema with, e.g., levels of categorical variables or min/max for splines.
   But we can get the _types_ of terms to be constructed before that.



1. Pull out types of data needed.
2. Generate contrasts matrices for each of the categorical eval terms.

# `@generated function` for tuple to model row

This is a function that takes a named tuple and generates a model matrix row.
Will pass contrasts matrices as arguments (somehow). I was going to say as a
named tuple but that won't work: might need different contrasts for different
terms.



In order to generate code, need to know how to 

1. How many columns for each term.
2. What kind of term each one is (continuous, categorical, interaction, etc.)