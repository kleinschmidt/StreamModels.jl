# once schema is set in formula, we can generate code to fill in the model
# matrix row-by-row.  how we do this depends on the streaming type of the
# source.  if we can get whole columns at a time, then we can efficiently
# convert categorical columns to efficient categorical variables.  otherwise, we
# have to do something like a dictionary lookup for each element.
#
# actually, I don't think it's any more efficient to convert a whole column at a
# time, if you already know the unique elements.  and it might even be possible
# to convert to the ref value in the tuple construction; then the anonymous
# function only needs to get the relevant row in the contrasts matrix.  not
# clear how much that buys us but it might simplify the code generating bit.
#
# so we have a Data.Schema and a Formula with the RHS with leaf nodes converted
# to Categorical/ContinuousTerms.  from this, need to generate two things:
# 
# 1. tuple factory that takes a Data.Source and creates a tuple iterator
# 2. function that takes one tuple and returns one model matrix row

function modelmatrix(source, f::Formula)
    tuple_iter = tuple_iterator(source)
    
    f = parse(f)
    symbols = get_symbols(f)
    sch = Data.schema(tuple_iter)
    # store the unique values for categorical variables in the schema
    categorical_cols = [s for s in symbols if is_categorical(s, sch)]

    get_unique!(tuple_iter, categorical_cols)
    set_schema!(f, sch)
    
    col_nums = Dict{Symbol,Int}(s=>sch[string(s)] for s in symbols)
    af = AnonFactory(f.rhs, col_nums)
    fill_row! = Function(af)

    reset!(tuple_iter)
    model_mat = zeros(length(tuple_iter), af.num_cols)
    for (i, t) in enumerate(tuple_iter)
        fill_row!(view(model_mat, i, :), t)
    end

    model_mat
end

