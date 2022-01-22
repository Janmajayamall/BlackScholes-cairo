"""contract.cairo test file."""
from decimal import Decimal
import os

import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.compiler.compile import compile_starknet_files
from py_vollib.black_scholes import black_scholes
from py_vollib.black_scholes.greeks.numerical import rho, gamma, theta, delta, vega
from py_vollib.ref_python.black import d1, d2
from random import seed
from random import uniform
import asyncio
import time

# The path to the contract source code.
CONTRACT_FILE = os.path.join("contracts", "blackscholes.cairo")

PRIME = 2 ** 251 + 17 * 2 ** 192 + 1
SCALE = 10 ** 27
def scale_to_high_precision(val):
    # print(val)
    return int(val * SCALE)

def random_input():
    # 1 sec to 10 years
    # tAnnualised = uniform(0.00000003174, 10)
    tAnnualised = uniform(1, 10)
    volatility=uniform(0.01, 0.3)
    rate=uniform(0, 0.5)
    spot=uniform(100, 10000)
    strike=uniform(100, 10000)

    return (
        tAnnualised,
        volatility,
        rate,
        spot, 
        strike
    )

def felt_to_decimal(felt):
    if (felt > PRIME // 2):
        return Decimal(felt - PRIME) / Decimal(SCALE)
    return Decimal(felt) / Decimal(SCALE)

def check(val1, val2):
    assert abs(Decimal(val1) - Decimal(val2)) < Decimal(0.001)

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

def calc_theta(spot,strike,tAnnualised,rate, volatility):
    call_theta = theta('c',spot,strike,tAnnualised,rate, volatility)
    put_theta = theta('p',spot,strike,tAnnualised,rate, volatility)
    return (call_theta, put_theta)

@pytest.mark.asyncio
async def run_test_iteration(contract, index):
    # iterations run simultaneously, this makes sure sur they run sequentially
    await asyncio.sleep(index)

    input = random_input()
    tAnnualised=input[0]
    volatility=input[1]
    rate=input[2]
    spot=input[3]
    strike=input[4]

    print("\n\n")
    print(input, "\n")
    

    # option prices
    res = await contract.option_prices(
        tAnnualised=scale_to_high_precision(tAnnualised),
        volatility=scale_to_high_precision(volatility),
        spot=scale_to_high_precision(spot),
        strike=scale_to_high_precision(strike),
        rate=scale_to_high_precision(rate)
    ).invoke()
    c_call = str(felt_to_decimal(res.result.call_price))
    c_put = str(felt_to_decimal(res.result.put_price))
    print("option prices")
    print(c_call, c_put)
    res = calc_option_prices(spot,strike,tAnnualised,rate, volatility)
    print(res[0], res[1])

    # check(c_call, res[0])
    # check(c_put, res[1])

    # print('\n')

    # theta
    # res = await contract.theta(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # c_call = str(felt_to_decimal(res.result.call_theta))
    # c_put = str(felt_to_decimal(res.result.put_theta))
    # print("theta")
    # print(c_call, c_put)
    # res = calc_theta(spot,strike,tAnnualised,rate, volatility)
    # print(res[0], res[1])

    # print('\n')

    # d1d2
    # res = await contract.d1d2(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # print("d1d2")
    # print(str(felt_to_decimal(res.result.d1)), str(felt_to_decimal(res.result.d2)))
    # res = calc_d1d2(spot,strike,tAnnualised,rate, volatility)
    # print(res[0], res[1])

    # print('\n')

    # # rho
    # res = await contract.rho(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # c_call_rho = str(felt_to_decimal(res.result.call_rho))
    # c_put_rho = str(felt_to_decimal(res.result.put_rho))
    # print("rho")
    # print(c_call_rho, c_put_rho)
    # res = calc_rho(spot,strike,tAnnualised,rate, volatility)
    # print(res[0], res[1])

    # print('\n')

    # # vega
    # res = await contract.vega(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # print("vega")
    # c_vega = str(felt_to_decimal(res.result.vega))
    # print(c_vega)
    # res = calc_vega(spot,strike,tAnnualised,rate, volatility)
    # print(res)

    # print('\n')

    # # gamma
    # res = await contract.gamma(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # c_gamma = str(felt_to_decimal(res.result.gamma))
    # print("gamma")
    # print(c_gamma)
    # res = calc_gamma(spot,strike,tAnnualised,rate, volatility)
    # print(res)

    # print('\n')

    # # delta
    # res = await contract.delta(
    #     tAnnualised=scale_to_high_precision(tAnnualised),
    #     volatility=scale_to_high_precision(volatility),
    #     spot=scale_to_high_precision(spot),
    #     strike=scale_to_high_precision(strike),
    #     rate=scale_to_high_precision(rate)
    # ).invoke()
    # print("delta")
    # c_call_delta = str(felt_to_decimal(res.result.call_delta))
    # c_put_delta = str(felt_to_decimal(res.result.put_delta))
    # print(c_call_delta, c_put_delta)
    # res = calc_delta(spot,strike,tAnnualised,rate, volatility)
    # print(res[0], res[1])

    print("\n")


# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_function():
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    compiled_contracts = compile_starknet_files([CONTRACT_FILE],  disable_hint_validation=True)

    # Deploy the contract.
    contract = await starknet.deploy(
        contract_def=compiled_contracts
    )
    
    coros = [run_test_iteration(contract, i) for i in range(10)]
    await asyncio.gather(*coros)

    assert False