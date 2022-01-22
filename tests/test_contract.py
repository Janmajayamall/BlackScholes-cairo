"""contract.cairo test file."""
import os

import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.compiler.compile import compile_starknet_files

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "blackscholes.cairo")

def scale_to_high_precision(val):
    return int(val * (10 ** 27))


# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_increase_balance():
    """Test increase_balance method."""
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    compiled_contracts = compile_starknet_files([CONTRACT_FILE],  disable_hint_validation=True)

    # Deploy the contract.
    contract = await starknet.deploy(
        contract_def=compiled_contracts
    )

    # d = await contract.d1d2(
    #     tAnnualised=scale_to_high_precision(1),
    #     volatility=(15 * 10 ** 25),
    #     spot=scale_to_high_precision(300),
    #     strike=scale_to_high_precision(250),
    #     rate=(3 * 10 ** 25)
    # ).invoke()
    d = await contract.exp(
        value=10 ** 27,
    ).invoke()
    print(d)
    assert False
    
    # Invoke increase_balance() twice.
    # await contract.increase_balance(amount=10).invoke()
    # await contract.increase_balance(amount=20).invoke()

    # # Check the result of get_balance().
    # execution_info = await contract.get_balance().call()
    # assert execution_info.result == (30,)
