import base58

from brownie import *
from config import BinanceTestnet

c = BinanceTestnet()


def get_deployer_account():
    if network.show_active().startswith("binance"):
        return accounts.load(c.DEPLOYER_BSC)
    else:
        return accounts.load(c.DEPLOYER_ETH)


def deploy():
    assert c.PARA_ORACLE != "", "You must first deploy the oracle."
    assert c.PARA_ORACLE_USER == "", "Oracle user already deployed."

    deployer_acc = get_deployer_account()

    oracle_user = OracleUserExample.deploy(c.PARA_ORACLE, {"from": deployer_acc})


def request():
    assert c.PARA_ORACLE_USER != "", "You must first deploy the oracle user."
    deployer_acc = get_deployer_account()

    # Get IPFS hash
    ipfs_hash = "QmTUFeBdxkGJsvFeTthwrYNwfkNWkE4e5P5f8goPdLoLGc"
    ipfs_bytes32 = base58.b58decode(ipfs_hash)[2:]

    nonce = 12
    oracle_user = OracleUserExample.at(c.PARA_ORACLE_USER)

    tx = oracle_user.initiateRequest(
        ipfs_bytes32, nonce, {"from": deployer_acc, "value": Wei("0.01 ether")}
    )
