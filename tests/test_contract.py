"""contract.cairo test file."""
import os

import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.compiler.compile import compile_starknet_files
from py_vollib.black_scholes import black_scholes
from py_vollib.black_scholes.greeks.numerical import rho, gamma, theta, delta, vega
from py_vollib.ref_python.black import d1, d2
from random import seed
from random import uniform
# seed(1)
# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "blackscholes.cairo")

def scale_to_high_precision(val):
    # print(val)
    return int(val * 10 ** 27)

def random_input():
    # 1 sec to 10 years
    tAnnualised = uniform(0.00000003174, 10)
    volatility=uniform(0.01, 0.95)
    rate=uniform(0, 0.5)
    spot=uniform(100, 100000)
    strike=uniform(100, 100000)

    return (
        tAnnualised,
        volatility,
        rate,
        spot, 
        strike
    )

def calc_option_prices(spot,strike,tAnnualised,rate, volatility):
    call = black_scholes('c',spot,strike,tAnnualised,rate, volatility) 
    put = black_scholes('p',spot,strike,tAnnualised,rate,volatility) 
    return (call, put)

def calc_rho(spot,strike,tAnnualised,rate, volatility):
    call = rho('c',spot,strike,tAnnualised,rate, volatility) 
    put = rho('p',spot,strike,tAnnualised,rate,volatility) 
    return (call, put)

def calc_vega(spot,strike,tAnnualised,rate, volatility):
    _vega = vega('c',spot,strike,tAnnualised,rate, volatility) 
    return _vega

def calc_gamma(spot,strike,tAnnualised,rate, volatility):
    _gamma = gamma('p',spot,strike,tAnnualised,rate, volatility) 
    return _gamma

def calc_delta(spot,strike,tAnnualised,rate, volatility):
    call_delta = delta('c',spot,strike,tAnnualised,rate, volatility)
    put_delta = delta('p',spot,strike,tAnnualised,rate, volatility)
    return (call_delta, put_delta)

def calc_d1d2(spot,strike,tAnnualised,rate, volatility):
    _d1 = d1(spot,strike,tAnnualised,rate, volatility)
    _d2 = d2(spot,strike,tAnnualised,rate, volatility)
    return (_d1, _d2)

@pytest.mark.asyncio
async def run_test_iteration(contract):
    input = random_input()
    tAnnualised=input[0]
    volatility=input[1]
    rate=input[2]
    spot=input[3]
    strike=input[4]

    # option prices
    res = await contract.optionPrices(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_call = res.result.call_price
    c_put = res.result.put_price
    print(c_call, c_put)
    
    res = calc_option_prices(spot,strike,tAnnualised,rate, volatility)
    print(res[0], res[1])

    print('\n')

    # d1d2
    res = await contract.d1d2(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    print(res.result.d1, res.result.d2)
    
    res = calc_d1d2(spot,strike,tAnnualised,rate, volatility)
    print(res[0], res[1])

    print('\n')

    # rho
    res = await contract.rho(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_call_rho = res.result.call_rho
    c_put_rho = res.result.put_rho
    print(c_call_rho, c_put_rho)

    res = calc_rho(spot,strike,tAnnualised,rate, volatility)
    print(res[0], res[1])

    print('\n')

    # vega
    res = await contract.vega(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_vega = res.result.vega
    print(c_vega)

    res = calc_vega(spot,strike,tAnnualised,rate, volatility)
    print(res)

    print('\n')

    # gamma
    res = await contract.gamma(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_gamma = res.result.gamma
    print(c_gamma)

    res = calc_gamma(spot,strike,tAnnualised,rate, volatility)
    print(res)

    print('\n')

    # delta
    res = await contract.delta(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_call_delta = res.result.call_delta
    c_put_delta = res.result.put_delta
    print(c_call_delta, c_put_delta)

    res = calc_delta(spot,strike,tAnnualised,rate, volatility)
    print(res[0], res[1])

    print("\n")


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
    
    await run_test_iteration(contract)
    # dq = await contract.d1d2(
    #     tAnnualised=scale_to_high_precision(1),
    #     volatility=(15 * 10 ** 25),
    #     spot=scale_to_high_precision(300343),
    #     strike=scale_to_high_precision(2502),
    #     rate=(3 * 10 ** 25)
    # ).invoke()
    # d = await contract.std_normal_cdf(
    #     x=32043898285580162156367708160,
    # ).invoke()
    # print(d)

    # # lib
    # call = black_scholes('c',spot,strike,tAnnualised,rate, volatility) 
    # put = black_scholes('p',spot,strike,tAnnualised,rate,volatility) 
    # print(call, put)

    # print(dq)
    assert False
    
    # Invoke increase_balance() twice.
    # await contract.increase_balance(amount=10).invoke()
    # await contract.increase_balance(amount=20).invoke()

    # # Check the result of get_balance().
    # execution_info = await contract.get_balance().call()
    # assert execution_info.result == (30,)
