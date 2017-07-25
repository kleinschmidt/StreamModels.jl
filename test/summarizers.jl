@testset "Summarizers" begin
    using Base.Test

    # requires Base NamedTuples and DataStreams/jq/gangy

    using DataStreams
    using StreamModels

    using StreamModels: RowIterator, update!

    source = Data.Table((a = collect(1:10),
                         b = rand(10),
                         c = repeat(["a", "b"], inner=5)))

    iter = RowIterator(source)
    sch = Data.schema(source)
    types = Dict(Symbol(k) => Data.types(sch)[sch[k]] for k in Data.header(sch))

    summ = StreamModels.make_summarizer(StreamModels.Terms.Eval(:c), types)

    for nt in iter
        update!(summ, nt)
    end

    @test unique(source[:c]) == summ.uniq

end #testset
