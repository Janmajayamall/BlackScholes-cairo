# Declare this file as a StarkNet contract and set the required
# builtins.
# %lang starknet
# %builtins pedersen range_check

from starkware.cairo.common.math_cmp import (
    is_le, is_nn
)
from starkware.cairo.common.math import (
    abs_value, signed_div_rem
)

const RC_BOUND = 2 ** 128
const DIV_BOUND = 170141183460469231731687303715884105728 # (2 ** 128) // 2
const HIGH_PRECISION = 10 ** 27
const HIGH_PRECISION_DIV_10 = 10 ** 26
const HIGH_PRECISION_TIMES_10 = 10 ** 28
const PRECISION = 10 ** 18

func check_rc_bound{
        range_check_ptr
    }(value: felt):
    abs_value(value)
    return()
end

func safe_add{
        range_check_ptr
    }(x: felt, y: felt) -> (z: felt):
    check_rc_bound(x)
    check_rc_bound(y)
    let z: felt = x + y
    check_rc_bound(z)
    return (z)
end

func safe_mul{
        range_check_ptr
    }(x: felt, y: felt) -> (z: felt):
    check_rc_bound(x)
    check_rc_bound(y)
    let z: felt = x * y
    check_rc_bound(z)
    return (z)
end

func safe_div{
        range_check_ptr
    }(x: felt, y:felt) -> (q: felt, r: felt):
    # x: divided, y: divisor, q: quotient, r: remainder
    # bound: 2**127

    # check for y != 0 is left intentionally
    # since signed_div_rem takes care of that
    check_rc_bound(x) 
    
    # bound == 2**127, the case when x will be out
    # of bound range is when x is max (i.e. +/- (2 ** 128) - 1)
    # and y is +/- 1; so just return x when y = 1
    # or -(x) when y = -1
    if y == 1:
        return (x, 0)
    end

    if y == -1:
        return (-1*x, 0)
    end


    # we cannot pass -ve div to signed_div_rem
    let y_nn: felt = is_nn(y)
    if y_nn == 0:
        # switch signs of x & y (i.e. multiple num & denom by -1)
        let s_x: felt = x * -1
        let s_y: felt = y * -1
        let (q, r) = signed_div_rem(s_x, s_y, DIV_BOUND) 
        return (q, r)
    else:
        let (q, r) = signed_div_rem(x, y, DIV_BOUND) 
        return (q, r)
    end

    # y can be left unchecked since
    # signed_div_rem asserts that dividend
    # is range 0 < ids.div <= PRIME // range_check_builtin.bound
    # i.e. 0 < ids.div <= approx 2 ** 122
end

func multiply_decimal_round_precise{
        range_check_ptr
    }(x: felt, y:felt) -> (z: felt):
    alloc_locals

    let z_mul: felt = safe_mul(x, y)
    let (z_mul_times_10, _) = safe_div(z_mul, HIGH_PRECISION_DIV_10)

    let (local z_div, z_r) = safe_div(z_mul_times_10, 10)

    let no_change: felt = is_le(z_r, 4)
    if no_change == 1:
        return (z_div)
    else:
        return (z_div + 1)
    end 
end

func divide_decimal_round_precise{
        range_check_ptr
    }(x: felt, y:felt) -> (z: felt):
    alloc_locals

    let num_times_10: felt = safe_mul(x, HIGH_PRECISION_TIMES_10)
    let (x_times_10, _) = safe_div(num_times_10, y)
    let (local x_mul, x_r) = safe_div(x_times_10, 10)
    let no_change: felt = is_le(x_r, 4)
    if no_change == 1:
        return(x_mul)
    else:
        return(x_mul + 1)
    end
end