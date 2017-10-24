# stragy: extra

mutable struct ModelBuilder{M}
    head::Symbol
    args::Tuple
    kw::Dict{Symbol,Any}
end

ModelBuilder(head::Symbol, args...; kw...) = new{head}(head, args, kw)



is_kw(ex) = Meta.isexpr(ex, :kw)

macro model(df, ex)
    @argcheck check_call(ex)
    println("I got $df and $ex")

    head = shift!(ex.args)
    kw_mask = is_kw.(ex.args)
    args = ex.args[.!kw_mask]
    kw = Dict(a.args[1]=>a.args[2] for a in ex.args[kw_mask])

    @show head
    @show args
    @show kw
end

macro model(ex)
    print("I got $ex")
end
