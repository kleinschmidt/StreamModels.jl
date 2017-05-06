
using DataFrames

import StreamModels: get_symbols, get_unique!, set_schema!, is_categorical
using DataStreams

source = DataFrame(a = collect(1:10),
                   b = rand(10),
                   c = repeat(["a", "b"], inner=5))
f = StreamModels.Formula(nothing, :(a*b*c))

################################################################################
# combine formula and Data.Schema

parse!(f.rhs)
symbols = vcat(get_symbols(f.lhs), get_symbols(f.rhs))

sch = Data.schema(source)

# store the unique values for categorical variables in the schema
for s in symbols
    if is_categorical(s, sch)
        get_unique!(sch, source, string(s))
    end
end

################################################################################
# now go through and do the whole aliasing thing

set_schema!(f.rhs, sch)

