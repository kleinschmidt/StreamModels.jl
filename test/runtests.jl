using StreamModels
using Test

@testset "StreamModels tests" begin
    include.(["formula.jl",
              "modelmatrix.jl",
              "summarizers.jl"])
end
