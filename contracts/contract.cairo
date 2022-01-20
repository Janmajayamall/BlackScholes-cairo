# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range, is_le_felt
)
from starkware.cairo.common.math import (
    assert_nn, sqrt
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

const MIN_EXP = -63 * HIGH_PRECISION

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

        ids.exp = s_exp
    %}
    return (res=exp)
end

func exp{range_check_ptr}(value: felt) -> (res: felt):

    
    return ()
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



@external
func d1d2{

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
    # take care of precision checks
end
