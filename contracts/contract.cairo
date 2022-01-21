# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range, is_le_felt
)
from starkware.cairo.common.math import (
    assert_nn, abs_value, sqrt
)
from safe_math import (
    safe_add, safe_mul, safe_div, multiply_decimal_round_precise, divide_decimal_round_precise, check_rc_bound
)

const RC_BOUND = 2 ** 128
# (2 ** 128) // 2
const DIV_BOUND = 170141183460469231731687303715884105728
const HIGH_PRECISION = 10 ** 27
const HIGH_PRECISION_DIV_10 = 10 ** 26
const HIGH_PRECISION_TIMES_10 = 10 ** 28
const PRECISION = 10 ** 18

const MIN_EXP = -64 * HIGH_PRECISION
const SQRT_TWOPI = 2506628274631000502415765285

const MIN_CDF_STD_DIST_INPUT = HIGH_PRECISION_DIV_10 * -45  # -4.5 
const MAX_CDF_STD_DIST_INPUT = HIGH_PRECISION_TIMES_10

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
    let root: felt = sqrt(value_times_precision)
    return(root)
end

func std_normal{
        range_check_ptr
    }(x: felt) -> (res: felt):
    let (x_div_2, r) = safe_div(x, 2)
    let (x_and_half) = multiply_decimal_round_precise(x, x_div_2)
    let (x_exp) = exp(-1 * x_and_half)
    let (res) = divide_decimal_round_precise(x_exp, SQRT_TWOPI)
    return(res)
end

func _std_normal_cdf_prob_helper{
        range_check_ptr
    }(
        to_add: felt,
        last_div: felt,
        t1: felt
    ) -> (res: felt):
    let add_res: felt = safe_add(last_div, to_add)
    let mul_res: felt = safe_mul(add_res, 10 ** 7)
    let (res, r) = safe_div(mul_res, t1)
    return (res)
end

func std_normal_cdf{
        range_check_ptr
    }(x: felt) -> (res: felt):
    alloc_locals

    # TODO check range

    let min_return: felt = is_le(x, MIN_CDF_STD_DIST_INPUT - 1)
    if min_return == 1:
        return(0)
    end

    let max_return: felt = is_le(MAX_CDF_STD_DIST_INPUT + 1, x)
    if max_return == 1:
        return(0)
    end

    let abs_x: felt = abs_value(x)
    let abs_x_mul: felt = multiply_decimal_round_precise(2315419, abs_x)
    let (local t1: felt) = safe_add(10 ** 7, abs_x_mul)

    let x_over_2: felt = safe_div(x, 2)
    let exponent: felt = multiply_decimal_round_precise(x, x_over_2)

    let exp_exponent: felt = exp(exponent)
    let d: felt = divide_decimal_round_precise(3989423, exp_exponent)

    # calc prob
    let first_div: felt = _std_normal_cdf_prob_helper(0, 13302740, t1)
    let second_div: felt = _std_normal_cdf_prob_helper(-18212560, first_div, t1)
    let third_div: felt = _std_normal_cdf_prob_helper(17814780, second_div, t1)
    let fourth_div: felt = _std_normal_cdf_prob_helper(-3565638, third_div, t1)
    
    let inter_add: felt = safe_add(fourth_div, 3193815)
    let inter_mul: felt = safe_mul(inter_add, 10 ** 7)
    let prob_num: felt = safe_mul(inter_mul, d)
    let (local prob, r_prob) = safe_div(prob_num, t1)

    let is_x_negative: felt = is_le(x, -1)
    if is_x_negative == 0:
        let _addition: felt = safe_add(10 ** 14, -1 * prob)
        let f_prob: felt = divide_decimal_round_precise(_addition, 10 ** 14)
        return(f_prob)
    else:
        let f_prob: felt = divide_decimal_round_precise(prob, 10 ** 14)
        return(f_prob)
    end
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

# @external
# func
