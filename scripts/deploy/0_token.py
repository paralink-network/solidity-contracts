from brownie import *

from config import MainnetConfig

c = MainnetConfig()


def main():
    assert c.PARA_TOKEN == "", "Token already deployed on mainnet."
    if network.show_active() == 'binance':
        deployer_acc = accounts.load(c.DEPLOYER_BSC)
    else:
        deployer_acc = accounts.load(c.DEPLOYER_ETH)

    publish_source = True
    _ = ParaToken.deploy(
        {"from": deployer_acc,
         "gas_price": int(web3.eth.gasPrice*c.GAS_MULTIPLIER)},
        publish_source=publish_source
    )
