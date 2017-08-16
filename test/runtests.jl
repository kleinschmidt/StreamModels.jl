using StreamModels
using Base.Test

@testset "StreamModels tests" begin
    include.(["formula.jl",
              "modelmatrix.jl",
              "summarizers.jl"])
end
