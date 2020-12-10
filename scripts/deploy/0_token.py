from brownie import *

from config import MainnetConfig

c = MainnetConfig()


def main():
    assert c.PARA_TOKEN == "", "Token already deployed on mainnet."
    deployer_acc = accounts.load(c.DEPLOYER)
    _ = ParaToken.deploy({"from": deployer_acc,
                          "gas_price": int(web3.eth.gasPrice*c.GAS_MULTIPLIER)})
