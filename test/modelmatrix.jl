module TestModelMatrix

using StreamModels
using Base.Test
using DataFrames
using StreamModels
using DataStreams

source = DataFrame(a = collect(1:10),
                   b = rand(10),
                   c = repeat(["a", "b"], inner=5))
f = StreamModels.Formula(nothing, :(a*b*c))

mm = modelmatrix(source, f)

@test size(mm) == (10, 8)
@test mm[:,1] == source[:a]
@test mm[:,2] == source[:b]
@test mm[:,3] == [ones(5); zeros(5)]
@test mm[:,4] == [zeros(5); ones(5)]
@test mm[:,5] == source[:a] .* source[:b]
@test mm[:,6] == source[:a] .* [zeros(5); ones(5)]
@test mm[:,7] == source[:b] .* [zeros(5); ones(5)]
@test mm[:,8] == source[:a] .* source[:b] .* [zeros(5); ones(5)]

end
