# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range, is_le_felt
)
from starkware.cairo.common.math import (
    assert_nn
)
from safe_math import (
    safe_add, safe_mul, multiply_decimal_round_precise, divide_decimal_round_precise, check_rc_bound
)

const RC_BOUND = 2 ** 128
# (2 ** 128) // 2
const DIV_BOUND = 170141183460469231731687303715884105728
const HIGH_PRECISION = 10 ** 27
const HIGH_PRECISION_DIV_10 = 10 ** 26
const HIGH_PRECISION_TIMES_10 = 10 ** 28
const PRECISION = 10 ** 18

const MIN_EXP = -64 * HIGH_PRECISION
consnt SQRT_TWOPI = 2506628274631000502415765285

func ln{range_check_ptr}(value: felt) -> (res: felt):
    alloc_locals
    local ln : felt
    %{
        from math import log
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.value)
        assert 0 < ids.value < range_check_builtin.bound

        # unscale value
        u_value = ids.value / (10 ** 27)

        # calc
        _ln = log(u_value)

        # scale ln
        s_ln_times_10 = _ln * (10 ** 28)
        if s_ln_times_10 % 10 >= 5:
            s_ln_times_10 += 10
        s_ln = s_ln_times_10 // 10

        ids.ln = int(s_ln)
    %}
    return (res=ln)
end

func _exp{range_check_ptr}(value: felt) -> (res: felt):
    alloc_locals
    local exp : felt
    %{
        from math import exp
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.value)
        assert 0 <= ids.value < range_check_builtin.bound

        # unscale value
        u_value = ids.value / (10 ** 27)

        # calc
        i_exp = exp(u_value)

        # scale exp
        s_exp_times_10 = i_exp * (10 ** 28)
        if s_exp_times_10 % 10 >= 5:
            s_exp_times_10 += 10
        s_exp = s_exp_times_10 // 10

        ids.exp = int(s_exp)

        assert 0 <= ids.exp < range_check_builtin.bound
    %}
    return (res=exp)
end

func exp{range_check_ptr}(value: felt) -> (res: felt):
    let nn: felt = is_nn(value)
    if nn == 1:
        let res: felt = _exp(value)
        return(res)
    else:
        let is_min: felt = is_le(value, MIN_EXP)
        if is_min == 1:
            return(0)
        else:
            let pos_res: felt = _exp(value * -1)
            let res: felt = divide_decimal_round_precise(HIGH_PRECISION, pos_res)
            return(res)
        end
    end
end

func sqrt_precise{
        range_check_ptr
    }(value: felt) -> (root: felt):
    # should not be -ve
    assert_nn(value)
    check_rc_bound(value)

    let value_times_precision: felt = safe_mul(value, HIGH_PRECISION)
    let root: felt = _sqrt(value_times_precision)
    return(root)
end

func std_normal{
        range_check_ptr
    }(x: felt) -> (res: felt):
    let (x_div_2, r): felt = safe_div(x, 2)
    let (x_and_half): felt = multiply_decimal_round_precise(x, x_div_2)
    let (x_exp): felt = exp(-1 * x_and_half)
    let (res): felt = divide_decimal_round_precise(x_exp, SQRT_TWOPI)
    return(res)
end

@external
func d1d2{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        d1: felt,
        d2: felt
    ):

    alloc_locals

    # TODO check value bounds
    # take care of precision checks

    let sqrt_tA: felt = sqrt_precise(tAnnualised)
    let (local vt_sqrt: felt) = multiply_decimal_round_precise(volatility, sqrt_tA)
    let spot_over_strike: felt = divide_decimal_round_precise(spot, strike)
    let (local log: felt) = ln(spot_over_strike)

    # calc v2t
    let v_over_2: felt = safe_div(volatility, 2)
    let v_and_half: felt = multiply_decimal_round_precise(volatility, v_over_2)
    let v_plus_rate: felt = safe_add(v_and_half, rate)
    let (local v2t: felt) = multiply_decimal_round_precise(v_plus_rate, tAnnualised)

    # calc d1
    let log_plus_v2: felt = safe_add(log, v2t)
    let (local d1: felt) = divide_decimal_round_precise(log_plus_v2, vt_sqrt)

    # calc d2
    let d2: felt = safe_add(d1, -1 * vt_sqrt)

    return (d1, d2)
end
