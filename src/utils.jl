is_call(ex::Expr) = Meta.isexpr(ex, :call)
is_call(ex::Expr, op::Symbol) = Meta.isexpr(ex, :call) && ex.args[1] == op
is_call(::Any) = false
is_call(::Any, ::Any) = false

"""
    is_formula(ex::Expr)

Detect formula expressions (either two-sided or one-sided).

"""
is_formula(ex::Expr) = is_call(ex, :~) || is_call(ex) && is_call(ex.args[2], :~)
is_formula(::Any) = false
