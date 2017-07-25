using StreamModels
using Base.Test

@testset "StreamModels tests" begin
    include.(["formula.jl",
              # "modelmatrix.jl",
              # "csv.jl",
              "summarizers.jl"])
end
