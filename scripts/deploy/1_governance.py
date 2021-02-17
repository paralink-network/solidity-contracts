from brownie import *
from config import Config

c = Config.get()


def main():
    assert c.PARA_TOKEN, "PARA Token not set"
    assert c.TIMELOCK == "", "Timelock is already deployed"
    assert c.GOVERNOR == "", "Governor is already deployed"
    deployer_acc = c.get_deployer_account()

    gov_delay = 2 * 24 * 3600  # 2 days
    admin_acc = deployer_acc.address
    timelock = Timelock.deploy(
        admin_acc,
        gov_delay,
        {"from": deployer_acc, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)},
    )

    guardian = deployer_acc.address
    gov = GovernorAlpha.deploy(
        timelock.address,
        c.PARA_TOKEN,
        guardian,
        {"from": deployer_acc, "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER)},
    )
