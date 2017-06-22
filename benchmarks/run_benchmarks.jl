using BenchmarkTools
using StreamModels
using DataStreams
using DataFrames

using StreamModels: @formula

source = DataFrame(a = collect(1:10),
                   b = rand(10),
                   c = repeat(["a", "b"], inner=5))

f = @formula( ~ a+b+c)

@benchmark StreamModels.parse!($f)

b = @benchmarkable modelmatrix(source, f)

# tune!(b)
# BenchmarkTools.save("params.jld", "b", params(b))

loadparams!(b, BenchmarkTools.load("params.jld", "b"))

run(b)
