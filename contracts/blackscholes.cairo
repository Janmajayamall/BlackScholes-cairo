# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range, is_le_felt
)
from starkware.cairo.common.math import (
    assert_nn, abs_value, sqrt, signed_div_rem
)
from contracts.safe_math import (
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

const MIN_T_ANNUALISED = 31709791983764586504
const MIN_VOLATILITY = 10 ** 23

func ln{range_check_ptr}(value: felt) -> (res: felt):
    alloc_locals
    
    local ln : felt
    local is_ln_neg: felt
    %{
        from math import log
        from starkware.cairo.common.math_utils import assert_integer

        assert_integer(ids.value)
        _value = as_int(ids.value, PRIME)
        assert 0 < _value

        # unscale value
        u_value = _value / (10 ** 27)

        # calc
        _ln = log(u_value)

        # scale ln
        s_ln_times_10 = _ln * (10 ** 28)

        # avoid math.floor or ceil to get
        # more accuracy
        if s_ln_times_10 % 10 >= 5:
            s_ln_times_10 += 10
        s_ln = s_ln_times_10 // 10

        ids.is_ln_neg = 1 if s_ln < 0 else 0
        
        ids.ln = int(abs(s_ln))
    %}
    if is_ln_neg == 1:
        return(-1 * ln)
    else:
        return(ln)
    end
end

func exp{range_check_ptr}(value: felt) -> (res: felt):
    alloc_locals
    local exp : felt
    %{
        from math import exp
        from starkware.cairo.common.math_utils import assert_integer, as_int
        
        assert_integer(ids.value)
        _value = as_int(ids.value, PRIME)
        
        # unscale value
        u_value = _value / (10 ** 27)
        
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

@external
func sqrt_precise{
        range_check_ptr
    }(value: felt) -> (root: felt):
    # should not be -ve
    # assert_nn(value)
    # check_rc_bound(value)

    # let x: felt = 1809251394333065606848661391547535052811553607665798349986546028067936010230
    # # let d: felt = multiply_decimal_round_precise(x, -1*x)
    
    # return(x * 100)

    let value_times_precision: felt = safe_mul(value, HIGH_PRECISION)
    # let (f, d) = signed_div_rem(value * HIGH_PRECISION, 2, 2 ** 127 - 1)
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

    let tA_min: felt = is_le(tAnnualised, MIN_T_ANNUALISED - 1)
    if tA_min == 1:
        return d1d2(MIN_T_ANNUALISED, volatility, spot, strike, rate)
    end

    let vol_min: felt = is_le(volatility, MIN_VOLATILITY - 1)
    if vol_min == 1:
        return d1d2(MIN_T_ANNUALISED, volatility, spot, strike, rate)
    end

    # calc v2t
    let v_sq: felt = multiply_decimal_round_precise(volatility, volatility)
    let v_sq_over_2: felt = safe_div(v_sq, 2)
    let v_plus_rate: felt = safe_add(v_sq_over_2, rate)
    let (local v2t: felt) = multiply_decimal_round_precise(v_plus_rate, tAnnualised)

    let sqrt_tA: felt = sqrt_precise(tAnnualised)
    let (local vt_sqrt: felt) = multiply_decimal_round_precise(volatility, sqrt_tA)
    let spot_over_strike: felt = divide_decimal_round_precise(spot, strike)
    let log: felt = ln(spot_over_strike)

    # calc d1
    let log_plus_v2: felt = safe_add(log, v2t)
    let (local d1: felt) = divide_decimal_round_precise(log_plus_v2, vt_sqrt)

    # calc d2
    let d2: felt = d1 - vt_sqrt

    return (d1, d2)
end

@external
func delta{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        call_delta: felt,
        put_delta: felt
    ):
    alloc_locals

    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local call_delta: felt) = std_normal_cdf(d1)
    let put_delta: felt = safe_add(call_delta, -1 * HIGH_PRECISION)
    return (call_delta, put_delta)
end


@external
func gamma{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        _gamma: felt
    ):
    alloc_locals

    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local s_n_d1: felt) = std_normal(d1)

     let tA_sqrt: felt = sqrt_precise(tAnnualised)
     let spot_times_ta_sqrt: felt = multiply_decimal_round_precise(spot, tA_sqrt)
     let v_spot_times_ta_sqrt: felt = multiply_decimal_round_precise(volatility, spot_times_ta_sqrt)

    let _gamma: felt = divide_decimal_round_precise(s_n_d1, v_spot_times_ta_sqrt)
    return (_gamma)
end


@external
func vega{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        _vega: felt
    ):
    alloc_locals
    let (local d1, _) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let std_d1: felt = std_normal(d1)
    let (local std_d1_times_spot: felt) = multiply_decimal_round_precise(std_d1, spot)
    
    let tA_sqrt: felt = sqrt_precise(tAnnualised)
    let _vega: felt = multiply_decimal_round_precise(tA_sqrt, std_d1_times_spot)
    return (_vega)
end


@external
func rho{
        range_check_ptr
    }(
        tAnnualised: felt,
		volatility: felt,
		spot: felt,
		strike: felt,
		rate: felt
    ) -> (
        call_rho: felt,
        put_rho: felt
    ):
    alloc_locals

    let (local s_t: felt) = multiply_decimal_round_precise(strike, tAnnualised)
    let r_t: felt = multiply_decimal_round_precise(rate, tAnnualised)
    let exp_rt: felt = exp(-1 * r_t)
    let (local inter: felt) = multiply_decimal_round_precise(s_t, exp_rt)

    # cdfs
    let (_, local d2: felt) = d1d2(tAnnualised, volatility, spot, strike, rate)
    let (local d2_cdf: felt) = std_normal_cdf(d2)
    let (local d2_neg_cdf: felt) = std_normal_cdf(d2 * -1)

    let (local call_rho: felt) = multiply_decimal_round_precise(inter, d2_cdf)
    let put_rho: felt = multiply_decimal_round_precise(inter, d2_neg_cdf)

    return (call_rho, -1 * put_rho)
end


# @external 
# func theta{
#         range_check_ptr
#     }(
# 		tAnnualised: felt,
#         volatility: felt,
#         spot: felt,
#         strike: felt,
#         rate: felt
#   ) -> (call_theta: felt, put_theta: felt)
    
# end

@external
func optionPrices{
        range_check_ptr
    }(
        tAnnualised: felt,
        volatility: felt,
        spot: felt,
        strike: felt,
        rate: felt
    ) -> (call_price: felt, put_price: felt):
    alloc_locals

    # TODO check input values

    # d1 d2
    let (local d1, local d2) = d1d2(tAnnualised, volatility, spot, strike, rate)

    # calc strikePv
    let rate_mul_tA: felt = multiply_decimal_round_precise(-1*rate, tAnnualised)
    let exp_rate_mul_tA: felt = exp(rate_mul_tA)
    let (local strike_pv: felt) = multiply_decimal_round_precise(strike, exp_rate_mul_tA)

    # calc spotNd1
    let s_cdf_d1: felt = std_normal_cdf(d1)
    let (local spotN_d1: felt) = multiply_decimal_round_precise(spot, s_cdf_d1)

    # calc strikeNd2
    let s_cdf_d2: felt = std_normal_cdf(d2)
    let (local strikeN_d2: felt) = multiply_decimal_round_precise(strike_pv, s_cdf_d2)

    let is_nd2_le_nd1: felt  = is_le(strikeN_d2, spotN_d1)
    if is_nd2_le_nd1 == 1:
        let (local _call: felt) = spotN_d1 - strikeN_d2 # replace this with safe add
        let inter_put: felt = safe_add(_call, strike_pv)
        let _is_spot_le_put: felt = is_le(spot, inter_put)
        if _is_spot_le_put == 1:
            let put: felt = inter_put - spot # replace this with safe add
            return (_call, put)
        else:
            return (_call, 0)
        end
    else:
        let _is_spot_le_strike_pv: felt = is_le(spot, strike_pv)
        if _is_spot_le_strike_pv == 1:
            let put: felt = strike_pv - spot # replace this with safe add
            return (0, put)
        else:
            return (0, 0)
        end
    end
end
