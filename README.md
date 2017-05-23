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

```julia
julia> using DataFrames, StreamModels
julia> source = DataFrame(a = collect(1:10),
+                         b = rand(10),
+                         c = repeat(["a", "b"], inner=5))
10×3 DataFrames.DataFrame
│ Row │ a  │ b         │ c   │
├─────┼────┼───────────┼─────┤
│ 1   │ 1  │ 0.883566  │ "a" │
│ 2   │ 2  │ 0.879327  │ "a" │
│ 3   │ 3  │ 0.366719  │ "a" │
│ 4   │ 4  │ 0.0910445 │ "a" │
│ 5   │ 5  │ 0.124422  │ "a" │
│ 6   │ 6  │ 0.169691  │ "b" │
│ 7   │ 7  │ 0.548005  │ "b" │
│ 8   │ 8  │ 0.255456  │ "b" │
│ 9   │ 9  │ 0.435064  │ "b" │
│ 10  │ 10 │ 0.670273  │ "b" │

julia> f = @formula( ~ a*b*c)
StreamModels.Formula(nothing,:(a * b * c))

julia> mm = modelmatrix(source, f)
10×8 Array{Float64,2}:
  1.0  0.883566   1.0  0.0  0.883566   0.0  0.0       0.0    
  2.0  0.879327   1.0  0.0  1.75865    0.0  0.0       0.0    
  3.0  0.366719   1.0  0.0  1.10016    0.0  0.0       0.0    
  4.0  0.0910445  1.0  0.0  0.364178   0.0  0.0       0.0    
  5.0  0.124422   1.0  0.0  0.622112   0.0  0.0       0.0    
  6.0  0.169691   0.0  1.0  1.01815    6.0  0.169691  1.01815
  7.0  0.548005   0.0  1.0  3.83603    7.0  0.548005  3.83603
  8.0  0.255456   0.0  1.0  2.04365    8.0  0.255456  2.04365
  9.0  0.435064   0.0  1.0  3.91557    9.0  0.435064  3.91557
 10.0  0.670273   0.0  1.0  6.70273   10.0  0.670273  6.70273
```

Note that there's no intercept by default, and hence the contrasts for the first
`c` term are properly promoted to "full rank" dummy coding.

### Arbitrary functions

Using code generation means we can (again) use arbitrary julia code in the
formula:

```julia
julia> modelmatrix(source, @formula(~1 + a + log(a) + log(a+b)))
10×4 Array{Float64,2}:
 1.0   1.0  0.0       0.482802
 1.0   2.0  0.693147  0.884687
 1.0   3.0  1.09861   1.26395 
 1.0   4.0  1.38629   1.49256 
 1.0   5.0  1.60944   1.6398  
 1.0   6.0  1.79176   1.81235 
 1.0   7.0  1.94591   2.01432 
 1.0   8.0  2.07944   2.11786 
 1.0   9.0  2.19722   2.21899 
 1.0  10.0  2.30259   2.3639  
```

### CSV source

For any source that's not random access, need to add a `reset!` method (until
that's part of the Data.Source interface).

```julia

julia> using CSV

julia> StreamModels.reset!(x::CSV.Source) = CSV.reset!(x)

julia> f = @formula(~ a*b*c)
StreamModels.Formula(nothing,:(a * b * c))

julia> source = CSV.Source(joinpath(Pkg.dir("StreamModels"), "test", "test.csv"))
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

julia> modelmatrix(source, f)
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

```

## Strategy

The general strategy is 

1. Parse the formula expression to a lowered form (like in StatsModels).

    ```julia
    julia> f = StreamModels.parse(@formula(~a*b*c))
    StreamModels.Formula(nothing,:(a + b + c + a & b + a & c + b & c + &(a,b,c)))
    ```

2. Set the schema from the data source in the formula, transforming symbol nodes
   in the formula AST into special representations of terms, `ContinuousTerm` or
   `CategoricalTerm`.  This requires first making one pass through the data to
   get the unique values for categorical columns, which is stored in the schema
   metadata.
   
    ```julia

    julia> sch = StreamModels.get_unique(source, [:c])
    Data.Schema{true}:
    rows: 10	cols: 3
    Columns:
    "a"  Int64  
    "b"  Float64
    "c"  String 

    julia> StreamModels.set_schema!(sch, f)
    StreamModels.Formula(nothing,:(a(Int64) + b(Float64) + c(StatsModels.FullDummyCoding{String}) + a(Int64) & b(Float64) + a(Int64) & c(StatsModels.DummyCoding{String}) + b(Float64) & c(StatsModels.DummyCoding{String}) + &(a(Int64),b(Float64),c(StatsModels.DummyCoding{String}))))
    ```
   
3. Generate a custom anonymous function based on the formula with schema which
   fills in a single row of the model matrix given a tuple of values.

    ```julia
    julia> fill_row_expr, mm_cols = anon_factory(f.rhs, col_nums)
    (:((##Modelmat row#286,##Data tuple#287)->begin  # /home/dave/.julia/v0.5/StreamModels/src/modelmatrix.jl, line 123:
                begin 
                    ##Modelmat row#286[1:1] = ##Data tuple#287[1]
                    ##Modelmat row#286[2:2] = ##Data tuple#287[2]
                    ##Modelmat row#286[3:4] = ([1.0 0.0; 0.0 1.0])[get(CategoricalArrays.CategoricalPool{String,UInt32}(["a","b"]),##Data tuple#287[3]),:]
                    ##Modelmat row#286[5:5] = kron(##Data tuple#287[1],##Data tuple#287[2])
                    ##Modelmat row#286[6:6] = kron(##Data tuple#287[1],([0.0; 1.0])[get(CategoricalArrays.CategoricalPool{String,UInt32}(["a","b"]),##Data tuple#287[3]),:])
                    ##Modelmat row#286[7:7] = kron(##Data tuple#287[2],([0.0; 1.0])[get(CategoricalArrays.CategoricalPool{String,UInt32}(["a","b"]),##Data tuple#287[3]),:])
                    ##Modelmat row#286[8:8] = kron(##Data tuple#287[1],##Data tuple#287[2],([0.0; 1.0])[get(CategoricalArrays.CategoricalPool{String,UInt32}(["a","b"]),##Data tuple#287[3]),:])
                end
            end),8)
    ```

    This generates a function with two arguments: a row vector to fill, and a
    tuple for the corresponding table row.  The contrast matrices for
    categorical terms are spliced into the function, as are the categorical
    pools used to index into those matrices (that part is probably very
    inefficient).  Note that this also returns the number of columns that the
    model matrix will have.

Using code generation allows for arbitrary functions and, in principle, to
customize based on the back end, without making strong assumptions about the
structure of the data store.  There's a small overhead from needing to compile
this function, but that's paid only once per model matrix.

