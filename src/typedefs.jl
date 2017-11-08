# What are the steps here?
# 1. construct Formula
# 2. get data summaries that you need.
# 3. set schema on Formula based on data types/summaries
# 4. convert tabular data row(s) into numerical row vector/matrix
#
# 1 can happen without data.  2 and 3 need types/invariants of data.  4 needs
# actual data values


# ModelBuilder is the step before data becomes available; captures arguments to
# a model constructor as formulae

# ModelFrame has a constructed model + the formulae/data/schema used to
# construct model.  I guess that's the model, the model builder, and the data
# source.

# ModelFrame provides the statsmodels API (fit!, predict, coef, etc.).  predict
# is implemented by passing all the formula-derived arguments and the fitted
# model object to `predict`.

# We go from ModelBuilder to ModelFrame by calling `build!(::ModelBuilder,
# source)`, with a `!` to indicate that the model builder will be modified in
# the process.
#
# what about when data is streaming?  we just need to get something that we can
# call fit! etc. on.  Those methods will need to include data anyway so it's not
# a huge deal...  and the model types will likely be different, too.  The
# important thing is that we have an abstraction that allows generating
# numerical representations on demand...to use OnlineStats interface we need to
# provide fit!(o::ModelFrame{<:OnlineStat}, obs, w) method.  The valued added
# here is that obs is a row (or chunk) of tabular data, which will somehow be
# converted into numerical data...
