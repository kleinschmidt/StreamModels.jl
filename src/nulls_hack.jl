## a garbage hack: just unwrap everything indiscriminately and pray that there's
## no nulls anywhere
_get(x) = x
_get{T}(x::Nullable{T}) = get(x)::T

## also unwrap types
_get{T}(::Type{Nullable{T}}) = T

