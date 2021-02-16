import base58
import pytest

import brownie
from brownie import *
from eth_abi import encode_abi


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


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
    fee = Wei("0.01 ether")
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1], "value": fee})

    assert oracle.withdrawableBalance() == 0
    assert len(tx.events) == 1
    request_event = tx.events["Request"][0]

    # Some data should not be by default 0
    assert user.someData() == hex(0)

    # Oracle fullfills the request
    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["fee"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )

    # The callback function should be successful
    assert fultx.return_value == True
    assert user.someData() == hex(123456)
    assert oracle.withdrawableBalance() == fee


def test_double_fulfill_fail(oracle, user, ipfs_bytes32):
    fee = Wei("0.01 ether")
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1], "value": fee})

    request_event = tx.events["Request"][0]

    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["fee"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )
    assert oracle.withdrawableBalance() == fee

    # Try to fulfill the second time
    with brownie.reverts("Must have a valid requestId"):
        fultx = oracle.fulfillRequest(
            request_event["requestId"],
            request_event["fee"],
            request_event["callbackAddress"],
            request_event["callbackFunctionId"],
            request_event["expiration"],
            hex(123456),
            {"from": accounts[0]},
        )

    assert oracle.withdrawableBalance() == fee

    # We can submit another request with same nonce after it is fulfilled
    user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1], "value": fee})


def test_subsequent_init_requests_with_same_nonce(oracle, user, ipfs_bytes32):
    user.initiateRequest(
        ipfs_bytes32, 0, {"from": accounts[1], "value": Wei("0.01 ether")}
    )

    with brownie.reverts("Must use a unique ID"):
        user.initiateRequest(
            ipfs_bytes32, 0, {"from": accounts[1], "value": Wei("0.01 ether")}
        )


def test_subsequent_init_requests_with_different_nonce(oracle, user, ipfs_bytes32):
    user.initiateRequest(
        ipfs_bytes32, 0, {"from": accounts[1], "value": Wei("0.01 ether")}
    )

    user.initiateRequest(
        ipfs_bytes32, 1, {"from": accounts[1], "value": Wei("0.01 ether")}
    )


def test_minimum_fee(oracle, user, ipfs_bytes32):
    minimumFee = oracle.minimumFee() - 1

    with brownie.reverts("Must send more than min fee."):
        tx = user.initiateRequest(
            ipfs_bytes32, 0, {"from": accounts[1], "value": minimumFee}
        )

    # Lower the fee
    oracle.setMinimumFee(minimumFee, {"from": accounts[0]})

    # The call should pass
    tx = user.initiateRequest(
        ipfs_bytes32, 0, {"from": accounts[1], "value": minimumFee}
    )


def test_cannot_withdraw_twice(oracle, user, ipfs_bytes32):
    fee = Wei("1 ether")
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1], "value": fee})
    request_event = tx.events["Request"][0]

    assert oracle.withdrawableBalance() == 0

    # Oracle fullfills the request
    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["fee"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )

    # Withdraw
    balance_before_withdraw = accounts[0].balance()

    oracle.withdraw(accounts[0], Wei("1 ether"))
    assert float(accounts[0].balance() - balance_before_withdraw) == pytest.approx(
        Wei("1 ether"), abs=Wei("0.01 ether")
    )
    assert oracle.withdrawableBalance() == 0

    with brownie.reverts("Amount requested is greater than withdrawable balance"):
        oracle.withdraw(accounts[0], Wei("1 ether"))


# ------- canceling requests -------
@pytest.fixture
def init_oracle_request(oracle, user, ipfs_bytes32):
    # High fee in order to not be swallowed by cancel tx fees
    fee = Wei("1 ether")
    tx = user.initiateRequest(ipfs_bytes32, 0, {"from": accounts[1], "value": fee})
    request_event = tx.events["Request"][0]

    return fee, request_event


def test_cancel_non_existing_request(user, init_oracle_request):
    fee, request_event = init_oracle_request

    with brownie.reverts("Params do not match request ID"):
        user.cancelRequest(666, fee, request_event["expiration"], {"from": accounts[1]})


def test_cancel_before_expiration(user, init_oracle_request):
    fee, request_event = init_oracle_request

    with brownie.reverts("Request is not expired"):
        user.cancelRequest(0, fee, request_event["expiration"], {"from": accounts[1]})


def test_cancel_success(user, init_oracle_request):
    fee, request_event = init_oracle_request
    balance_before_cancel = accounts[1].balance()

    chain.sleep(int(request_event["expiration"]) - chain.time())
    user.cancelRequest(0, fee, request_event["expiration"], {"from": accounts[1]})

    assert float(accounts[1].balance()) == pytest.approx(
        balance_before_cancel + fee, abs=Wei("0.01 ether")
    )


def test_fulfill_after_cancel(oracle, user, init_oracle_request):
    fee, request_event = init_oracle_request
    balance_before_cancel = accounts[1].balance()

    chain.sleep(int(request_event["expiration"]) - chain.time())
    user.cancelRequest(0, fee, request_event["expiration"], {"from": accounts[1]})

    # Cannot fulfill after the request was cancelled
    with brownie.reverts("Must have a valid requestId"):
        fultx = oracle.fulfillRequest(
            request_event["requestId"],
            request_event["fee"],
            request_event["callbackAddress"],
            request_event["callbackFunctionId"],
            request_event["expiration"],
            hex(123456),
            {"from": accounts[0]},
        )


def test_cancel_after_fulfill(oracle, user, init_oracle_request):
    fee, request_event = init_oracle_request
    balance_before_cancel = accounts[1].balance()

    assert oracle.withdrawableBalance() == 0

    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["fee"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(123456),
        {"from": accounts[0]},
    )

    assert oracle.withdrawableBalance() == fee

    # Cannot cancel after the request was fulfilled
    chain.sleep(int(request_event["expiration"]) - chain.time())
    with brownie.reverts("Params do not match request ID"):
        user.cancelRequest(0, fee, request_event["expiration"], {"from": accounts[1]})

    assert oracle.withdrawableBalance() == fee


def test_complex_flow(oracle, ipfs_bytes32):
    fee = Wei("1 ether")

    node_operator = accounts[0]

    # Three consumers of the oracle
    consumers = [accounts[i] for i in range(1, 4)]
    consumer_contracts = [
        OracleUserExample.deploy(oracle.address, {"from": consumer})
        for consumer in consumers
    ]

    # Every consumer spawns three requests
    requests = {
        consumer: [
            contract.initiateRequest(ipfs_bytes32, i, {"from": consumer, "value": fee})
            for i in range(0, 3)
        ]
        for consumer, contract in zip(consumers, consumer_contracts)
    }

    assert oracle.withdrawableBalance() == 0

    # Fulfill first request of every consumer
    for i, (consumer, request_list) in enumerate(requests.items()):
        request_event = request_list[0].events["Request"][0]

        fultx = oracle.fulfillRequest(
            request_event["requestId"],
            request_event["fee"],
            request_event["callbackAddress"],
            request_event["callbackFunctionId"],
            request_event["expiration"],
            hex(i + 50),
            {"from": node_operator},
        )

    # Oracle should make some money
    assert oracle.withdrawableBalance() == Wei("3 ether")
    balance_before_withdraw = node_operator.balance()

    oracle.withdraw(node_operator, Wei("3 ether"))
    assert float(node_operator.balance() - balance_before_withdraw) == pytest.approx(
        Wei("3 ether"), abs=Wei("0.01 ether")
    )

    # Consumer contract should have the result
    for i, contract in enumerate(consumer_contracts):
        contract.someData() == hex(i + 50)

    assert oracle.withdrawableBalance() == 0

    # Cancel every second request
    for i, (consumer, request_list) in enumerate(requests.items()):
        request_event = request_list[1].events["Request"][0]

        balance_before_cancel = consumer.balance()

        chain.sleep(int(request_event["expiration"]) - chain.time())
        consumer_contracts[i].cancelRequest(
            1, fee, request_event["expiration"], {"from": consumer}
        )

        # Consumer should get his funds back
        assert float(consumer.balance() - balance_before_cancel) == pytest.approx(
            Wei("1 ether"), abs=Wei("0.01 ether")
        )

    # Fulfill final request of every consumer
    for i, (consumer, request_list) in enumerate(requests.items()):
        request_event = request_list[2].events["Request"][0]

        fultx = oracle.fulfillRequest(
            request_event["requestId"],
            request_event["fee"],
            request_event["callbackAddress"],
            request_event["callbackFunctionId"],
            request_event["expiration"],
            hex(i + 100),
            {"from": node_operator},
        )

    # Oracle should make some money
    assert oracle.withdrawableBalance() == Wei("3 ether")
    balance_before_withdraw = node_operator.balance()

    oracle.withdraw(node_operator, Wei("3 ether"))
    assert float(node_operator.balance() - balance_before_withdraw) == pytest.approx(
        Wei("3 ether"), abs=Wei("0.01 ether")
    )

    # Consumer contract should have the new result
    for i, contract in enumerate(consumer_contracts):
        contract.someData() == hex(i + 100)

    assert oracle.withdrawableBalance() == 0
