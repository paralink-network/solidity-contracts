import base58
from brownie import *


def main():
    oracle_owner = accounts[0]
    lottery_owner = accounts[1]

    oracle = ParalinkOracle.deploy({"from": oracle_owner})
    lottery = Lottery.deploy(oracle.address, {"from": lottery_owner})

    # Lottery owner start the lottery
    lottery.startLottery()

    # Participants enter the lottery
    for i in range(2, 6):
        lottery.participate({"from": accounts[i], "value": "0.005 ether"})

    # Wait for lottery to expire
    chain.sleep(3601)

    # Print the participants
    print("Participants: ", *enumerate(lottery.getParticipants()))

    # Lottery owner starts oracle request to pick the winner
    tx = lottery.pickWinner({"from": lottery_owner, "value": "0.01 ether"})

    # Oracle submits the random number
    random_number = 3
    request_event = tx.events["Request"][0]
    fultx = oracle.fulfillRequest(
        request_event["requestId"],
        request_event["fee"],
        request_event["callbackAddress"],
        request_event["callbackFunctionId"],
        request_event["expiration"],
        hex(random_number),
        {"from": oracle_owner},
    )

    # Show the winner
    print("The winner is: ", fultx.events)
