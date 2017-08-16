@testset "Formulas" begin 

    using StreamModels: sort_terms!, parse!

    @testset "Formula parsing" begin

        @testset "Associative property" begin
            @test parse!(:(a+(b+c))) == parse!(:(a+b+c))
            @test parse!(:((a+b)+c)) == parse!(:(a+b+c))
            @test parse!(:(a&(b&c))) == parse!(:(a&b&c))
            @test parse!(:((a&b)&c)) == parse!(:(a&b&c))
        end

        @testset "Distributive property" begin
            @test parse!(:(a & (b+c))) == parse!(:(a&b + a&c))
            @test parse!(:((a+b) & c)) == parse!(:(a&c + b&c))
            @test parse!(:((a+b) & (c+d))) == parse!(:(a&c + a&d + b&c + b&d))
            @test parse!(:(a & (b+c) & d)) == parse!(:(a&b&d + a&c&d))
        end
        
        @testset "Expand * to main effects + interactions" begin
            @test parse!(:(a*b)) == parse!(:(a+b+a&b))
            @test sort_terms!(parse!(:(a*b*c))) == parse!(:(a+b+c+a&b+a&c+b&c+a&b&c))
            @test parse!(:(a + b*c)) == parse!(:(a + b + c + b&c))
            @test parse!(:(a*b + c)) == parse!(:(a + b + a&b + c))
        end

    end

    # @testset "@formula" begin

    #     @test (@formula(y ~ x)) == Formula(:y, :x)
    #     @test (@formula(y ~ 1)) == Formula(:y, 1)
    #     @test (@formula(y ~ 1 + x)) == Formula(:y, :(1+x))

    #     @test (@formula( ~ x)) == Formula(nothing, :x)
    #     @test (@formula( ~ 1)) == Formula(nothing, 1)
    #     @test (@formula( ~ 1 + x)) == Formula(nothing, :(1+x))

    # end

end
