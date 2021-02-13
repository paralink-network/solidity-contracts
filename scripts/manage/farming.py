from brownie import *
from config import Config
import time

from eth_abi import encode_abi

c = Config.get()

deployer_acc = c.get_deployer_account()
para = ParaToken.at(c.PARA_TOKEN)
farm = ParaFarming.at(c.PARA_FARMING)
# timelock = Timelock.at(c.TIMELOCK)


def get_opts(from_=deployer_acc) -> dict:
    return {"from": from_, "gas_price": int(web3.eth.gasPrice * 1.3)}


# pid:[lp_addr, alloc_point]
uniswap_pools_1 = {
    0: ["", 100],  # PARA-ETH
    1: ["", 100],  # PARA-USDT
}
pools_update_to = {
    0: ["", 200],  # PARA-ETH
    1: ["", 100],  # PARA-USDT
}


def prevent_double_add(lp_addr: str):
    for i in range(100):
        try:
            pool = farm.poolInfo(i)
        except ValueError:
            break
        assert pool[0] != lp_addr, "Pool already exists"


def initialize_pools(pools: dict):
    """Setup initial UniswapV2-LP farms"""
    for lp_addr, alloc_point in list(pools.values()):
        prevent_double_add(lp_addr)
        farm.addPool(alloc_point, lp_addr, get_opts())
    time.sleep(30)
    farm.massUpdatePools({"from": deployer_acc})


def update_pools(pools: dict):
    farm.massUpdatePools({"from": deployer_acc})
    for pid, (lp_addr, alloc_point) in pools.items():
        print(f"Changing pool {pid} ({lp_addr}) to {alloc_point}")
        change_pool_alloc(pid, lp_addr, alloc_point)

    time.sleep(30)
    farm.massUpdatePools({"from": deployer_acc})


def add_pool(lp_addr: str, alloc_point: int):
    """Manually add a pool (ie. Uniswap PARA-ETH)"""
    prevent_double_add(lp_addr)
    farm.addPool(alloc_point, lp_addr, get_opts())


def change_pool_alloc(pid: int, lp_addr: str, alloc_point: int):
    """Change pool rewards allocation"""
    assert farm.poolInfo(pid)[0] == lp_addr, "Wrong pool id/addr"
    farm.setPool(pid, alloc_point, get_opts())


def update_pool(pid: int):
    """Call this to manually update revenue numbers.
    Typically necessary in production."""
    farm.updatePool(pid, get_opts())


def mint_rewards(amount: int):
    """Generate tokens for the farm."""
    amount = Wei(f"{amount} ether")
    para.mint(farm.address, amount, get_opts())


def set_rewards(amount: int):
    amount = Wei(f"{amount} ether")
    farm.setReward(amount, get_opts())


def enable_timelock():
    farm.transferOwnership(c.TIMELOCK, get_opts())


def initialize_pools_timelock(pools: dict, action: str, eta: int):
    for lp_addr, alloc_point in list(pools.values()):
        prevent_double_add(lp_addr)
        exec_timelock(
            action,
            farm.address,
            "add(uint256,address,bool)",
            encode_abi(["uint256", "address", "bool"], [alloc_point, lp_addr, False]),
            eta,
        )


def update_pools_timelock(pools: dict, action: str, eta: int):
    for pid, (lp_addr, alloc_point) in pools.items():
        assert farm.poolInfo(pid)[0] == lp_addr, "Wrong pool id/addr"
        print(f"Changing pool {pid} ({lp_addr}) to {alloc_point}")
        exec_timelock(
            action,
            farm.address,
            "set(uint256,unit256,bool)",
            encode_abi(["uint256", "uint256", "bool"], [pid, alloc_point, False]),
            eta,
        )


def exec_timelock(action: str, address: str, signature: str, abi: bytes, eta: int):
    if action == "queue":
        timelock_fn = timelock.queueTransaction
    if action == "execute":
        timelock_fn = timelock.executeTransaction
    if action == "cancel":
        timelock_fn = timelock.cancelTransaction

    timelock_fn(
        address,
        0,  # send no eth
        signature,
        abi,
        eta,
        {**get_opts(), "gas_limit": 2_000_000},
    )


#
# User facing functions
#
def invest(pid_):
    lp = ParaToken.at(uniswap_pools_1[pid_][0])
    available = int(lp.balanceOf(deployer_acc.address) * 0.1)
    print("\n\nAVAILABLE:", available)
    lp.approve(farm.address, 0, get_opts())
    lp.approve(farm.address, available, get_opts())
    farm.deposit(pid_, available, get_opts())


def pending(pid_):
    lp_addr = uniswap_pools_1[pid_][0]
    pending = farm.pendingRewards(pid_, deployer_acc.address)
    print(f"Pending in {lp_addr}:", round(pending * 1e-18, 2), "para")


def main():
    # initialize_pools(uniswap_pools_1)
    # update_pools(pools_update_to)
    # mint_rewards(100_000)

    # invest(1)
    pending(0)
    pending(1)

    pass
