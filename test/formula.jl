import StreamModels: sort_terms!

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
