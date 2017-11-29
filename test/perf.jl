# 
using StreamModels
using Test
using DataStreams

using StreamModels: @formula, set_schema!, modelmatrow!

source = Data.Table((a = collect(1:10),
                     b = rand(10),
                     c = repeat(["a", "b"], inner=5)))

f = @formula ~ 1+a
set_schema!(f, Data.schema(source))

iter = Data.rows(source)
rows = collect(iter)

modelmatrow!(zeros(2), rows[end], (f.terms...))

modelmatrow!(zeros(2), rows[end], (f.terms...))
@code_warntype modelmatrow!(zeros(2), rows[end], (f.terms...))
@code_typed modelmatrow!(zeros(2), rows[end], (f.terms...))
@code_llvm modelmatrow!(zeros(2), rows[end], (f.terms...))
