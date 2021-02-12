from brownie import *

from config import BinanceTestnet

c = BinanceTestnet()


def main():
    assert c.PARA_ORACLE == "", "Oracle already deployed."
    if network.show_active().startswith("binance"):
        deployer_acc = accounts.load(c.DEPLOYER_BSC)
    else:
        deployer_acc = accounts.load(c.DEPLOYER_ETH)

    publish_source = True
    oracle = ParalinkOracle.deploy(
        {"from": deployer_acc, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)},
        publish_source=publish_source,
    )
