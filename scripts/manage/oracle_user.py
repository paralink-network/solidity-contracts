import base58

from brownie import *
from config import Config

c = Config.get()
deployer_acc = c.get_deployer_account()


def deploy():
    assert c.PARA_ORACLE != "", "You must first deploy the oracle."
    assert c.PARA_ORACLE_USER == "", "Oracle user already deployed."

    oracle_user = OracleUserExample.deploy(
        c.PARA_ORACLE,
        {"from": deployer_acc, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)},
    )


def request():
    assert c.PARA_ORACLE_USER != "", "You must first deploy the oracle user."

    # Get IPFS hash
    ipfs_hash = "QmTUFeBdxkGJsvFeTthwrYNwfkNWkE4e5P5f8goPdLoLGc"
    ipfs_bytes32 = base58.b58decode(ipfs_hash)[2:]

    nonce = 13
    oracle_user = OracleUserExample.at(c.PARA_ORACLE_USER)

    tx = oracle_user.initiateRequest(
        ipfs_bytes32,
        nonce,
        {
            "from": deployer_acc,
            "value": Wei("0.01 ether"),
            "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER),
        },
    )
