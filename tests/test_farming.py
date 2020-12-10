import pytest

import brownie
from brownie import *
from eth_abi import encode_abi


@pytest.fixture
def para_token():
    yield ParaToken.deploy({'from': accounts[0]})


@pytest.fixture
def para_farming(para_token):
    current_block = web3.eth.blockNumber
    para_per_block = web3.toWei(1, 'ether')
    yield ParaFarming.deploy(para_token.address,
                             para_per_block,
                             current_block+100,
                             {'from': accounts[0]})



def test_farming(para_token, para_farming):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    # farm tokens
    token_1 = ParaToken.deploy({'from': accounts[0]})
    token_2 = ParaToken.deploy({'from': accounts[0]})
    token_3 = ParaToken.deploy({'from': accounts[0]})

    # setup farms with 90/10/0% allocations
    para_farming.addPool(90, token_1)
    para_farming.addPool(10, token_2)
    para_farming.addPool(0,  token_3)
    assert para_farming.totalAllocPoint() == 100

    # pid's
    farm_1, farm_2, farm_3 = list(range(3))

    # farmers
    alice   = accounts[0]
    bob     = accounts[1]
    charlie = accounts[2]

    # give farmers initial tokens
    token_1.mint(alice.address,   1000, {'from': accounts[0]})
    token_2.mint(bob.address,     1000, {'from': accounts[0]})
    token_2.mint(alice.address,   1000, {'from': accounts[0]})
    token_3.mint(charlie.address, 1000, {'from': accounts[0]})

    # farmers deposit their tokens
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})
    token_2.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})
    token_2.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": bob})
    token_3.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": charlie})

    para_farming.deposit(farm_1, 1000, {"from": alice})
    para_farming.deposit(farm_2, 1000, {"from": alice})
    para_farming.deposit(farm_2, 1000, {"from": bob})
    para_farming.deposit(farm_3, 1000, {"from": charlie})


    # 100 blocks = 100 PARA in rewards, split per allos
    chain.mine(para_farming.startBlock() - web3.eth.blockNumber)
    chain.mine(100)
    assert para_farming.pendingRewards(farm_1, alice.address) == web3.toWei(90, 'ether')
    assert para_farming.pendingRewards(farm_2, alice.address) == web3.toWei(5, 'ether')
    assert para_farming.pendingRewards(farm_2, bob.address) == web3.toWei(5, 'ether')
    assert para_farming.pendingRewards(farm_3, charlie.address) == web3.toWei(0, 'ether')

    # deposit rewards
    para_token.mint(para_farming.address, web3.toWei(999999, 'ether'))

    # lets do withdrawals
    # these tests are super hacky since each invocation moves block number forward,
    # changing the reward amount.
    para_farming.withdraw(farm_1, 1000, {"from": alice})
    pending_rewards = web3.eth.blockNumber - para_farming.startBlock()
    assert para_token.balanceOf(alice.address) == web3.toWei(0.90 * pending_rewards, 'ether')

    pending_rewards_alice = para_farming.pendingRewards(farm_2, alice.address)
    para_farming.withdraw(farm_2, 1000, {"from": alice})
    # close enough
    assert str(para_token.balanceOf(alice.address))[:3] \
        == str(int(web3.toWei(0.90 * pending_rewards, 'ether') + pending_rewards_alice))[:3]

    pending_rewards_bob = para_farming.pendingRewards(farm_2, bob.address)
    para_farming.withdraw(farm_2, 1000, {"from": bob})
    assert para_token.balanceOf(bob.address) >= web3.toWei(0.05 * pending_rewards, 'ether')
    assert para_token.balanceOf(bob.address) <= web3.toWei(0.1 * pending_rewards, 'ether')
    # assert para_token.balanceOf(bob.address) == pending_rewards_bob

    para_farming.withdraw(farm_3, 1000, {"from": charlie})
    assert para_token.balanceOf(charlie.address) == 0

    assert(token_1.balanceOf(para_farming.address) == 0)
    assert(token_2.balanceOf(para_farming.address) == 0)
    assert(token_3.balanceOf(para_farming.address) == 0)

    assert(token_1.balanceOf(alice.address)   == 1000)
    assert(token_2.balanceOf(alice.address)   == 1000)
    assert(token_2.balanceOf(bob.address)     == 1000)
    assert(token_3.balanceOf(charlie.address) == 1000)



def test_farming_insufficient(para_token, para_farming):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    # farm tokens
    token_1 = ParaToken.deploy({'from': accounts[0]})
    token_2 = ParaToken.deploy({'from': accounts[0]})
    token_3 = ParaToken.deploy({'from': accounts[0]})

    # setup farms with 90/10/0% allocations
    para_farming.addPool(90, token_1)
    para_farming.addPool(10, token_2)
    para_farming.addPool(0,  token_3)
    assert para_farming.totalAllocPoint() == 100

    # pid's
    farm_1, farm_2, farm_3 = list(range(3))

    # farmers
    alice   = accounts[0]
    bob     = accounts[1]
    charlie = accounts[2]

    # give farmers initial tokens
    token_1.mint(alice.address,   1000, {'from': accounts[0]})
    token_2.mint(bob.address,     1000, {'from': accounts[0]})
    token_2.mint(alice.address,   1000, {'from': accounts[0]})
    token_3.mint(charlie.address, 1000, {'from': accounts[0]})

    # farmers deposit their tokens
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})
    token_2.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})
    token_2.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": bob})
    token_3.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": charlie})

    para_farming.deposit(farm_1, 1000, {"from": alice})
    para_farming.deposit(farm_2, 1000, {"from": alice})
    para_farming.deposit(farm_2, 1000, {"from": bob})
    para_farming.deposit(farm_3, 1000, {"from": charlie})


    # 100 blocks = 100 PARA in rewards, split per allos
    chain.mine(para_farming.startBlock() - web3.eth.blockNumber)
    chain.mine(100)
    assert para_farming.pendingRewards(farm_1, alice.address) == web3.toWei(90, 'ether')
    assert para_farming.pendingRewards(farm_2, alice.address) == web3.toWei(5, 'ether')
    assert para_farming.pendingRewards(farm_2, bob.address) == web3.toWei(5, 'ether')
    assert para_farming.pendingRewards(farm_3, charlie.address) == web3.toWei(0, 'ether')

    # lets deposit insufficient rewards
    para_token.mint(para_farming.address, 42)

    # lets do withdrawals
    para_farming.withdraw(farm_1, 1000, {"from": alice})
    para_farming.withdraw(farm_2, 1000, {"from": alice})
    para_farming.withdraw(farm_2, 1000, {"from": bob})
    para_farming.withdraw(farm_3, 1000, {"from": charlie})

    assert(token_1.balanceOf(para_farming.address) == 0)
    assert(token_2.balanceOf(para_farming.address) == 0)
    assert(token_3.balanceOf(para_farming.address) == 0)

    assert(token_1.balanceOf(alice.address)   == 1000)
    assert(token_2.balanceOf(alice.address)   == 1000)
    assert(token_2.balanceOf(bob.address)     == 1000)
    assert(token_3.balanceOf(charlie.address) == 1000)

    # only alice got partially paid
    assert para_token.balanceOf(alice.address) == 42
    assert para_token.balanceOf(bob.address) == 0
    assert para_token.balanceOf(charlie.address) == 0

    # deposits become disabled after new rewards cant get paid out
    para_farming.deposit(farm_1, 100, {"from": alice})
    chain.mine(1)
    with brownie.reverts():
        para_farming.deposit(farm_1, 100, {"from": alice})


def test_beneficiary_farming(para_token, para_farming):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    # single farm setup
    farm_1 = 0
    token_1 = ParaToken.deploy({'from': accounts[0]})
    para_farming.addPool(100, token_1)
    assert para_farming.totalAllocPoint() == 100

    alice   = accounts[0]
    bob     = accounts[1]
    charlie = accounts[2]

    # give farmers initial tokens
    token_1.mint(alice.address,   1000, {'from': accounts[0]})
    token_1.mint(bob.address,     1000, {'from': accounts[0]})
    token_1.mint(charlie.address, 1000, {'from': accounts[0]})
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": bob})
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": charlie})

    # charlie deposits for alice
    para_farming.deposit(farm_1, 1000, {"from": alice})
    para_farming.deposit(farm_1, 1000, {"from": bob})
    para_farming.depositFor(alice.address, farm_1, 1000, {"from": charlie})

    # deposit rewards
    para_token.mint(para_farming.address, web3.toWei(999999, 'ether'))


    # 100 blocks = 100 PARA in rewards, split per allos
    chain.mine(para_farming.startBlock() - web3.eth.blockNumber)
    chain.mine(100)
    assert roughly_equal(para_farming.pendingRewards(farm_1, alice.address),
                         web3.toWei(200/3, 'ether'))
    assert roughly_equal(para_farming.pendingRewards(farm_1, bob.address),
                         web3.toWei(100/3, 'ether'))
    assert para_farming.pendingRewards(farm_1, charlie.address) == web3.toWei(0, 'ether')

    # charlie cannot take alice's rewards
    para_farming.depositFor(alice.address, farm_1, 0, {"from": charlie})
    assert para_token.balanceOf(alice.address) >= web3.toWei(200/3, 'ether')
    assert para_token.balanceOf(alice.address) < web3.toWei(70, 'ether')
    assert para_token.balanceOf(charlie.address) == 0


def roughly_equal(amount_a, amount_b) -> bool:
    amount_a = int(round(amount_a * 1e-16, 0))
    amount_b = int(round(amount_b * 1e-16, 0))
    return amount_a == amount_b


def test_emergency_withdraw(para_token, para_farming):
    farm_1 = 0
    alice = accounts[0]
    token_1 = ParaToken.deploy({'from': accounts[0]})
    token_1.mint(alice.address,   1000, {'from': accounts[0]})
    token_1.approve(para_farming.address, web3.toWei(9999999, 'ether'), {"from": alice})

    # initialize the farm
    para_farming.addPool(100, token_1)
    assert para_farming.totalAllocPoint() == 100
    para_farming.deposit(farm_1, 1000, {"from": alice})

    # generate rewards
    chain.mine(200)
    assert para_farming.pendingRewards(farm_1, alice.address) > 0
    para_token.mint(para_farming.address, 42)

    # do the emergency withdraw
    para_farming.emergencyWithdraw(farm_1, {"from": alice})
    assert(token_1.balanceOf(para_farming.address) == 0)
    assert(token_1.balanceOf(alice.address) == 1000)

    # make sure rewards have been nullified
    assert para_farming.pendingRewards(farm_1, alice.address) == 0
    assert para_token.balanceOf(alice.address) == 0
    assert para_token.balanceOf(para_farming.address) == 42
