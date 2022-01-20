# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range,
    is_le_felt)

from safe_math import (
    safe_add, safe_mul, safe_div
)

# 1e27

const RC_BOUND = 2 ** 128

@view
func multiply_decimal_round_precise{

    }(x: felt, y:felt) -> (z: felt):
    let z: felt = safe_mul(x, y) / (PRECISION / 10)
end