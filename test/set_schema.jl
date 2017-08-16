@testset "Instantiate eval terms with schema" begin

    using Base.Test
    # requires Base NamedTuples and DataStreams/jq/gangy
    using DataStreams
    using StreamModels

    using StreamModels: summarize!, set_schema!, termsyms, aliassyms

    source = Data.Table((a = collect(1:10),
                         b = rand(10),
                         c = repeat(["a", "b"], inner=5)))

    f = @formula ~ a*b*c
    sch = Data.schema(source)
    summarize!(sch, source, f)

    set_schema!(f, sch)
    
end
