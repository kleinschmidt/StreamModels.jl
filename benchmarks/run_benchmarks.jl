using BenchmarkTools
using StreamModels
using DataStreams
using DataFrames

using StreamModels: @formula

n = 100_000
source = DataFrame(a = collect(1:n),
                   b = rand(n),
                   c = repeat(["a", "b"], inner=n>>1))



f = @formula( ~ a)

@benchmark StreamModels.parse!($f)

b = @benchmarkable modelmatrix(source, f)

# tune!(b)
# BenchmarkTools.save("params.jld", "b", params(b))

loadparams!(b, BenchmarkTools.load("params.jld", "b"))
source2 = copy(source)
pool!(source2, :c)
ff = DataFrames.Formula(f.lhs, f.rhs)

b2 = @benchmark ModelMatrix(ModelFrame($ff, $source2))

run(b)
