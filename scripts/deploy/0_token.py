from brownie import *

from config import Config

c = Config.get()


def main():
    assert c.PARA_TOKEN == "", "Token already deployed on mainnet."
    deployer_acc = c.get_deployer_account()

    publish_source = True
    _ = ParaToken.deploy(
        {"from": deployer_acc, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)},
        publish_source=publish_source,
    )
