import base58
import pytest

import brownie
from brownie import *
from eth_abi import encode_abi


@pytest.fixture
def oracle():
    yield ParalinkOracle.deploy({"from": accounts[0]})


@pytest.fixture
def user(oracle):
    yield OracleUserExample.deploy(oracle.address, {"from": accounts[1]})


@pytest.fixture
def ipfs_bytes32():
    ipfs_hash = "QmTUFeBdxkGJsvFeTthwrYNwfkNWkE4e5P5f8goPdLoLGc"
    return base58.b58decode(ipfs_hash)[2:]


def test_successful_callback(oracle, user, ipfs_bytes32):
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1]})

    assert len(tx.events) == 1
    request_event = tx.events["Request"][0]

    # Some data should not be by default 0
    assert user.someData() == hex(0)

    # Oracle fullfills the request
    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )

    # The callback function should be successful
    assert fultx.return_value == True
    assert user.someData() == hex(123456)


def test_double_fulfill_fail(oracle, user, ipfs_bytes32):
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1]})

    request_event = tx.events["Request"][0]

    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )

    # Try to fulfill the second time
    with brownie.reverts("Must have a valid requestId"):
        fultx = oracle.fulfillRequest(
            request_event["requestId"],
            request_event["callbackAddress"],
            request_event["callbackFunctionId"],
            request_event["expiration"],
            hex(123456),
            {"from": accounts[0]},
        )
