using CSV
using DataStreams
using DataFrames

@testset "CSV source" begin

    StreamModels.reset!(x::CSV.Source) = CSV.reset!(x)
    f = @formula(~ a*b*c)

    @testset "No nulls" begin
        source = CSV.Source(joinpath(Pkg.dir("StreamModels"), "test", "test.csv"))
        df = CSV.read(source, DataFrame)

        reset!(source)
        @test modelmatrix(source, f) == modelmatrix(df, f)
    end

    @testset "Nulls" begin
        source = CSV.Source(joinpath(Pkg.dir("StreamModels"), "test", "test_null.csv"))
        @test_throws NullException modelmatrix(source, f)
    end

end
