import pytest

import brownie
from brownie import *
from eth_abi import encode_abi


@pytest.fixture
def para_token():
    yield ParaToken.deploy({'from': accounts[0]})


@pytest.fixture
def timelock():
    gov_delay = 2 * 24 * 3600  # 2 days
    admin_acc = accounts[0]
    yield Timelock.deploy(admin_acc, gov_delay, {'from': accounts[0]})


def test_timelock(para_token, timelock):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    para_token.transferOwnership(timelock.address, {'from': accounts[0]})

    with brownie.reverts("Ownable: caller is not the owner"):
        para_token.mint(accounts[0], 1000, {'from': accounts[0]})

    # schedule a mint
    delay = 50 * 3600
    eta = web3.eth.getBlock('latest')['timestamp'] + delay
    timelock.queueTransaction(
        para_token.address,
        0, # send no eth
        "mint(address,uint256)",
        encode_abi(['address', 'uint256'], [accounts[0].address, 100]),
        eta,
        {'from': accounts[0]},
    )

    # cannot execute until timelock is expired
    with brownie.reverts():
        timelock.executeTransaction(
            para_token.address,
            0, # send no eth
            "mint(address,uint256)",
            encode_abi(['address', 'uint256'], [accounts[0].address, 100]),
            eta,
            {'from': accounts[0]},
        )

    # advance the blockchain
    while chain.time() < eta:
        chain.mine(100)
        chain.sleep(24 * 3600)

    # execute transaction
    timelock.executeTransaction(
        para_token.address,
        0, # send no eth
        "mint(address,uint256)",
        encode_abi(['address', 'uint256'], [accounts[0].address, 100]),
        eta,
        {'from': accounts[0]},
    )

    # verify the effect
    assert para_token.balanceOf(accounts[0]) == 100

    # cannot execute again
    with brownie.reverts():
        timelock.executeTransaction(
            para_token.address,
            0, # send no eth
            "mint(address,uint256)",
            encode_abi(['address', 'uint256'], [accounts[0].address, 100]),
            eta,
            {'from': accounts[0]},
        )
    assert para_token.balanceOf(accounts[0]) == 100



