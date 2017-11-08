@testset "Summarizers" begin
    using Test

    # requires Base NamedTuples and DataStreams/jq/gangy

    using DataStreams
    using StreamModels

    using StreamModels: RowIterator, update!, summarize, CategoricalSummarizer, make_summarizer

    source = Data.Table((a = collect(1:10),
                         b = rand(10),
                         c = repeat(["a", "b"], inner=5)))
    sch = Data.schema(source)
    types = Dict(Symbol(k) => Data.types(sch)[sch[k]] for k in Data.header(sch))

    @testset "CategoricalSummarizer computes unique values" begin
        iter = RowIterator(source)

        summ = StreamModels.make_summarizer(StreamModels.Terms.Eval(:c), types)

        for nt in iter
            update!(summ, nt)
        end

        @test unique(source[:c]) == summ.uniq
    end

    @testset "If no summaries are needed, none are calculated" begin
        sch = summarize(source, @formula(~ 1 + a * b))
        @test !haskey(sch.metadata, :summaries)
    end
        
    @testset "One summarizer per unique variable" begin
        f = @formula( ~ 1 + a + b + c + c)
        summarizers = unique(reduce(vcat, [], make_summarizer(t, types) for t in f.term.rhs))
        @test length(summarizers) == 1

        f = @formula( ~ 1 + a*b*c)
        summarizers = unique(reduce(vcat, [], make_summarizer(t, types) for t in f.term.rhs))
        @test length(summarizers) == 1
    end

    @testset "Unique values stored in sch.metadata for categorical variables" begin
        sch = summarize(source, @formula( ~ c))
        @test collect(keys(sch.metadata[:summaries])) == Any[:c]
        @test collect(keys(sch.metadata[:summaries][:c])) == Any[:unique]
        @test sch.metadata[:summaries][:c][:unique] == unique(source[:c])
    end
end #testset
