


# StreamModels

[![Build Status](https://travis-ci.org/kleinschmidt/StreamModels.jl.svg?branch=master)](https://travis-ci.org/kleinschmidt/StreamModels.jl)
[![codecov.io](http://codecov.io/github/kleinschmidt/StreamModels.jl/coverage.svg?branch=master)](http://codecov.io/github/kleinschmidt/StreamModels.jl?branch=master)

This is a prototype of a different approach to generating numerical model
matrices based on tabular data and a formula.  It works with any data source
that satisfies
the
[DataStreams `Data.Source` interface](http://juliadata.github.io/DataStreams.jl/stable/),
including in-memory stores like DataFrames/DataTables, as well as databases and
files on disk like CSV and Feather.

At the moment, the interface is minimal: a `modelmatrix` function that takes a
a `Data.Source` and a `Formula`

## Examples

### DataFrame source

````julia
julia> using DataFrames, StreamModels, CSV

julia> using StreamModels: @formula    # because it's exported by DataFrames

julia> source = CSV.read(Pkg.dir("StreamModels", "test", "test.csv"))
10×3 DataFrames.DataFrame
│ Row │ a  │ b         │ c   │
├─────┼────┼───────────┼─────┤
│ 1   │ 1  │ 0.0447625 │ "a" │
│ 2   │ 2  │ 0.208667  │ "a" │
│ 3   │ 3  │ 0.559094  │ "a" │
│ 4   │ 4  │ 0.67986   │ "a" │
│ 5   │ 5  │ 0.373885  │ "a" │
│ 6   │ 6  │ 0.0971734 │ "b" │
│ 7   │ 7  │ 0.427763  │ "b" │
│ 8   │ 8  │ 0.780171  │ "b" │
│ 9   │ 9  │ 0.238685  │ "b" │
│ 10  │ 10 │ 0.501005  │ "b" │

julia> mm = modelmatrix(source, @formula( ~ a*b*c))
10×8 Array{Float64,2}:
  1.0  0.0447625  1.0  0.0  0.0447625   0.0  0.0        0.0    
  2.0  0.208667   1.0  0.0  0.417334    0.0  0.0        0.0    
  3.0  0.559094   1.0  0.0  1.67728     0.0  0.0        0.0    
  4.0  0.67986    1.0  0.0  2.71944     0.0  0.0        0.0    
  5.0  0.373885   1.0  0.0  1.86942     0.0  0.0        0.0    
  6.0  0.0971734  0.0  1.0  0.58304     6.0  0.0971734  0.58304
  7.0  0.427763   0.0  1.0  2.99434     7.0  0.427763   2.99434
  8.0  0.780171   0.0  1.0  6.24137     8.0  0.780171   6.24137
  9.0  0.238685   0.0  1.0  2.14817     9.0  0.238685   2.14817
 10.0  0.501005   0.0  1.0  5.01005    10.0  0.501005   5.01005

````





Note that there's no intercept by default, and hence the contrasts for the first
`c` term are properly promoted to "full rank" dummy coding.

### Arbitrary functions

Using code generation means we can (again) use arbitrary julia code in the
formula:

````julia
julia> modelmatrix(source, @formula(~1 + a + b + log(a) + log(a+b)))
10×5 Array{Float64,2}:
 1.0   1.0  0.0447625  0.0       0.0437896
 1.0   2.0  0.208667   0.693147  0.792389 
 1.0   3.0  0.559094   1.09861   1.26951  
 1.0   4.0  0.67986    1.38629   1.54327  
 1.0   5.0  0.373885   1.60944   1.68155  
 1.0   6.0  0.0971734  1.79176   1.80783  
 1.0   7.0  0.427763   1.94591   2.00522  
 1.0   8.0  0.780171   2.07944   2.1725   
 1.0   9.0  0.238685   2.19722   2.2234   
 1.0  10.0  0.501005   2.30259   2.35147  

````





### CSV source

For any source that's not random access, need to add a `reset!` method (until
that's part of the Data.Source interface).

````julia
julia> StreamModels.reset!(x::CSV.Source) = CSV.reset!(x)

julia> csv_source = CSV.Source(Pkg.dir("StreamModels", "test", "test.csv"))
CSV.Source: /home/dave/.julia/v0.5/StreamModels/test/test.csv
    CSV.Options:
        delim: ','
        quotechar: '"'
        escapechar: '\\'
        null: ""
        dateformat: Base.Dates.DateFormat(Base.Dates.Slot[Base.Dates.DelimitedSlot{Base.Dates.Year}(Base.Dates.Year,'y',4,"-"),Base.Dates.DelimitedSlot{Base.Dates.Month}(Base.Dates.Month,'m',2,"-"),Base.Dates.DelimitedSlot{Base.Dates.Day}(Base.Dates.Day,'d',2,r"(?=\s|$)")],"","english")
Data.Schema{true}:
rows: 10	cols: 3
Columns:
 "a"  Nullable{Int64}               
 "b"  Nullable{Float64}             
 "c"  Nullable{WeakRefString{UInt8}}

julia> modelmatrix(csv_source, @formula( ~ a*b*c))
10×8 Array{Float64,2}:
  1.0  0.0447625  1.0  0.0  0.0447625   0.0  0.0        0.0    
  2.0  0.208667   1.0  0.0  0.417334    0.0  0.0        0.0    
  3.0  0.559094   1.0  0.0  1.67728     0.0  0.0        0.0    
  4.0  0.67986    1.0  0.0  2.71944     0.0  0.0        0.0    
  5.0  0.373885   1.0  0.0  1.86942     0.0  0.0        0.0    
  6.0  0.0971734  0.0  1.0  0.58304     6.0  0.0971734  0.58304
  7.0  0.427763   0.0  1.0  2.99434     7.0  0.427763   2.99434
  8.0  0.780171   0.0  1.0  6.24137     8.0  0.780171   6.24137
  9.0  0.238685   0.0  1.0  2.14817     9.0  0.238685   2.14817
 10.0  0.501005   0.0  1.0  5.01005    10.0  0.501005   5.01005

````





## Strategy

The general strategy is 

### Parse the formula

Given an expression, it's transformed into a form where all the special forms
(like `*`) are expanded, and the associative/distributive rules are applied
where appropriate (for `+` and `&`).  This is based on `StatsModels` but uses a
slightly different approach.

````julia
julia> using StreamModels: parse!

julia> f = parse!(@formula( ~ a*b*c))
 ~ a + b + c + a & b + a & c + b & c + &(a,b,c)

````





### Set the schema in the formula

Given a data source, we need to extract its schema and combine it with the
Formula.  This is done by transforming symbol nodes in the formula AST into
special representations of terms to be evaluated from the data, `ContinuousTerm`
or `CategoricalTerm`.  This requires first making one pass through the data to
get the unique values for categorical columns, which are then stored in the
schema metadata.  At this phase contrasts matrices are constructed for
categorical variables and stored on the `CategoricalTerm`s.

This stage requires both the data schema and the parsed formula because we need
to know the types of the variables _and_ whether any given term "aliases" lower
order terms in order to know which contrasts to use.

For now, we rely on a special wrapper for a `Data.Source` which provides an
iterator over tuples that unwraps `Nullable` values (because the state of
nullables is up in the air and I'm lazy).

````julia
julia> using StreamModels: tuple_iterator, get_unique!, set_schema!

julia> iter = get_unique!(tuple_iterator(source), [:c])
StreamModels.FieldTupleIterator{true,Tuple{Int64,Float64,WeakRefString{UInt8}},3}(10×3 DataFrames.DataFrame
│ Row │ a  │ b         │ c   │
├─────┼────┼───────────┼─────┤
│ 1   │ 1  │ 0.0447625 │ "a" │
│ 2   │ 2  │ 0.208667  │ "a" │
│ 3   │ 3  │ 0.559094  │ "a" │
│ 4   │ 4  │ 0.67986   │ "a" │
│ 5   │ 5  │ 0.373885  │ "a" │
│ 6   │ 6  │ 0.0971734 │ "b" │
│ 7   │ 7  │ 0.427763  │ "b" │
│ 8   │ 8  │ 0.780171  │ "b" │
│ 9   │ 9  │ 0.238685  │ "b" │
│ 10  │ 10 │ 0.501005  │ "b" │,Data.Schema{true}:
rows: 10	cols: 3
Columns:
 "a"  Nullable{Int64}               
 "b"  Nullable{Float64}             
 "c"  Nullable{WeakRefString{UInt8}},1)

julia> sch = Data.schema(iter); set_schema!(f, sch)

````





### Generate an anonymous function to fill one row at a time

This step is handled by the `AnonFactory` type, which holds onto the metadata
required to generate code for each of the terms in the formula, as well as the
generated expressions themselves.

````julia
julia> using StreamModels: AnonFactory, get_symbols, model_function_exp

julia> col_nums = Dict(s=>sch[string(s)] for s in get_symbols(f))
Dict{Symbol,Int64} with 3 entries:
  :c => 3
  :a => 1
  :b => 2

julia> af = AnonFactory(f.rhs, col_nums);

julia> fill_row! = Function(af)
(::#43) (generic function with 1 method)

````





You can get the expression that's `eval`ed to get the actual function with

````julia
julia> model_function_exp(af)
quote  # /home/dave/.julia/v0.5/StreamModels/src/anonfactory.jl, line 48:
    let ##ContrMat c#290 = [1.0 0.0; 0.0 1.0], ##CatPool c#291 = CategoricalArrays.CategoricalPool{WeakRefString{UInt8},UInt32}(["a","b"]), ##ContrMat c#292 = [0.0; 1.0], ##CatPool c#293 = CategoricalArrays.CategoricalPool{WeakRefString{UInt8},UInt32}(["a","b"]) # /home/dave/.julia/v0.5/StreamModels/src/anonfactory.jl, line 49:
        (##Modelmat row#288,##Data tuple#289)->begin  # /home/dave/.julia/v0.5/StreamModels/src/anonfactory.jl, line 49:
                begin  # /home/dave/.julia/v0.5/StreamModels/src/anonfactory.jl, line 50:
                    ##Modelmat row#288[1] = ##Data tuple#289[1]
                    ##Modelmat row#288[2] = ##Data tuple#289[2]
                    ##Modelmat row#288[3:4] = ##ContrMat c#290[get(##CatPool c#291,##Data tuple#289[3]),:]
                    ##Modelmat row#288[5:5] = kron(##Data tuple#289[1],##Data tuple#289[2])
                    ##Modelmat row#288[6:6] = kron(##Data tuple#289[1],##ContrMat c#292[get(##CatPool c#293,##Data tuple#289[3]),:])
                    ##Modelmat row#288[7:7] = kron(##Data tuple#289[2],##ContrMat c#292[get(##CatPool c#293,##Data tuple#289[3]),:])
                    ##Modelmat row#288[8:8] = kron(##Data tuple#289[1],##Data tuple#289[2],##ContrMat c#292[get(##CatPool c#293,##Data tuple#289[3]),:])
                end
            end
    end
end

````





This function takes two arguments: a row vector to fill, and a tuple for the
corresponding table row.  Main effects of continuous variables are just copied
over to the output vector.  Interactions are generated via kronecker product of
the main effects (reducing to multiplication for continuous terms).  Categorical
values are converted to the correct row of a contrasts matrix and copied to the
output.  The categorical pools and contrast matrices are spliced into a `let`
block that surrounds the body of the function.

Using code generation allows for arbitrary functions and, in principle, to
customize based on the back end, without making strong assumptions about the
structure of the data store.  There's a small overhead from needing to compile
this function, but that's paid only once per model matrix.

