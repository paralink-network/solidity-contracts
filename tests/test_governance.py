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

@pytest.fixture
def governor(para_token, timelock):
    guardian = accounts[0]
    yield GovernorAlpha.deploy(timelock.address, para_token.address, guardian,
                               {'from': accounts[0]})



def test_governance(para_token, timelock, governor):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    # give some tokens to deployer
    alice = accounts[0]
    bob   = accounts[1]
    para_token.mint(alice, 1000, {'from': accounts[0]})

    # transfer admin rights to the DAO
    timelock.setPendingAdmin(governor.address, {'from': accounts[0]})
    governor.__acceptAdmin({'from': accounts[0]})

    # transfer control to the timelock
    para_token.transferOwnership(timelock.address, {'from': accounts[0]})

    # can no longer mint directly
    with brownie.reverts("Ownable: caller is not the owner"):
        para_token.mint(accounts[0], 1000, {'from': accounts[0]})

    # can no longer schedule mint directly
    with brownie.reverts("Timelock::queueTransaction: Call must come from admin."):
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

    # can not create a proposal unless 1% delegated votes
    with brownie.reverts("GovernorAlpha::propose: proposer votes below proposal threshold"):
        governor.propose(
            [para_token.address],
            [0], # send no eth
            ["mint(address,uint256)"],
            [encode_abi(['address', 'uint256'], [accounts[0].address, 100])],
            'RIP-42: Print Money',
            {'from': alice},
        )

    # alice delegates her votes to bob, making him a proposer
    para_token.delegate(bob, {'from': alice})

    # bob can make a proposal
    governor.propose(
        [para_token.address],
        [0], # send no eth
        ["mint(address,uint256)"],
        [encode_abi(['address', 'uint256'], [accounts[0].address, 100])],
        'RIP-42: Print Money',
        {'from': bob},
    )

    chain.mine(1)

    # bob can vote on his proposal, making it pass-able
    proposal_id = 1  # id == counter
    governor.castVote(proposal_id, True, {"from": bob})

    # we have to wait for voting period to end
    with brownie.reverts("GovernorAlpha::queue: proposal can only be queued if it is succeeded"):
        governor.queue(1)

    # after the voting period, proposal can be queued
    chain.mine(governor.votingPeriod())
    governor.queue(1)

    # have to wait for the timelock
    with brownie.reverts():
        governor.execute(1)

    # advance the blockchain
    delay = 50 * 3600
    eta = web3.eth.getBlock('latest')['timestamp'] + delay
    while chain.time() < eta:
        chain.sleep(24 * 3600)
        chain.mine(1)

    # finally execute the proposal
    governor.execute(1)

    # check if the balance is right after proposed minting
    assert para_token.balanceOf(accounts[0]) == 1100
