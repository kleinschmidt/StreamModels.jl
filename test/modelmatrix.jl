@testset "Model matrix" begin

    using StreamModels
    using Base.Test
    using DataFrames
    using StreamModels
    using DataStreams

    using StreamModels: @formula

    source = DataFrame(a = collect(1:10),
                       b = rand(10),
                       c = repeat(["a", "b"], inner=5))

    @testset "single term RHS" begin

        @test all(modelmatrix(source, @formula(~ 1)) .== 1)
        @test all(modelmatrix(source, @formula(~ a)) .== float(source[:a]))
        @test all(modelmatrix(source, @formula(~ b)) .== source[:b])
        @test all(modelmatrix(source, @formula(~ c)) .== [ones(5)  zeros(5)
                                                          zeros(5) ones(5)])

    end

    @testset "star expansion" begin
        f = @formula( ~ a*b*c)

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

    @testset "arbitrary functions" begin

        @test modelmatrix(source, @formula(~ log(a)))[:,1] == log.(float(source[:a]))
        @test modelmatrix(source, @formula(~ log(1+a)))[:,1] == log.(1.+float(source[:a]))
        @test modelmatrix(source, @formula(~ 1 + log(a))) == [ones(10) log.(float(source[:a]))]
        @test modelmatrix(source, @formula(~ log(a+b)))[:,1] == log.(source[:a].+source[:b])
        ## @test modelmatrix(source, @formula(~ log(a*b)))[:,1] == log.(source[:a].*source[:b])

    end

end
