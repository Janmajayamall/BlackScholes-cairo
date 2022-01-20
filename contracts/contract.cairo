# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import (
    is_not_zero, is_nn, is_le, is_nn_le, is_in_range, is_le_felt
    )

from safe_math import (
    safe_add, safe_mul
)


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
