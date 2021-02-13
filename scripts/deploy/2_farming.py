from brownie import *
from config import Config

c = Config.get()


def main():
    assert c.PARA_TOKEN, "PARA Token not set"
    assert c.PARA_FARMING == "", "ParaFarming is already deployed"

    deployer_acc = c.get_deployer_account()

    def get_opts(from_=deployer_acc) -> dict:
        return {"from": from_, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)}

    # block times
    # https://etherscan.io/chart/blocktime
    blocks_per_hour = int(3600 // 13.05)
    current_block = web3.eth.blockNumber
    start_block = current_block + (1 * blocks_per_hour)
    para_per_block = web3.toWei(1, "ether")
    print("Farming params:", para_per_block, start_block)

    farming = ParaFarming.deploy(c.PARA_TOKEN, para_per_block, start_block, get_opts())
