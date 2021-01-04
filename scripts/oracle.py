import base58

from brownie import *


def main():
    oracle = ParalinkOracle.deploy({"from": accounts[0]})

    oracle_user = OracleUserExample.deploy(oracle.address, {"from": accounts[1]})

