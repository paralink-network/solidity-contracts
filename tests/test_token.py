import pytest

import brownie
from brownie import *


@pytest.fixture
def para_token():
    yield ParaToken.deploy({'from': accounts[0]})


def test_deployment(para_token):
    assert para_token.name() == "Paralink Network"
    assert para_token.symbol() == "PARA"
    assert para_token.totalSupply() == 0


def test_minting(para_token):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    # admin can mint into their own account
    para_token.mint(accounts[0], 1000)
    assert para_token.balanceOf(accounts[0]) == 1000
    assert para_token.totalSupply() == 1000

    # or someone elses
    para_token.mint(accounts[1], 9999)
    assert para_token.balanceOf(accounts[1]) == 9999
    assert para_token.totalSupply() == 1000 + 9999

    # only admin can mint
    with brownie.reverts("Ownable: caller is not the owner"):
        para_token.mint(accounts[0], 1000, {"from": accounts[1]})


def test_zero_minting(para_token):
    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0

    para_token.mint(accounts[0], 0)

    assert para_token.totalSupply() == 0
    assert para_token.balanceOf(accounts[0]) == 0



def test_burning(para_token):
    para_token.mint(accounts[1], 1000)
    assert para_token.balanceOf(accounts[1]) == 1000

    # user can burn their own tokens
    para_token.burn(500, {"from": accounts[1]})
    assert para_token.balanceOf(accounts[1]) == 500

    # they cannot burn tokens they don't have
    with brownie.reverts("ERC20: burn amount exceeds balance"):
        para_token.burn(500, {"from": accounts[0]})


def test_revoke_admin(para_token):
    para_token.renounceOwnership()
    assert para_token.owner() == '0x0000000000000000000000000000000000000000'
    with brownie.reverts("Ownable: caller is not the owner"):
        para_token.mint(accounts[0], 1000)


def test_change_admin(para_token):
    para_token.transferOwnership(accounts[1])
    assert para_token.owner() == accounts[1]

    with brownie.reverts("Ownable: caller is not the owner"):
        para_token.mint(accounts[0], 1000)

    para_token.mint(accounts[1], 1000, {"from": accounts[1]})
    assert para_token.balanceOf(accounts[1]) == 1000
