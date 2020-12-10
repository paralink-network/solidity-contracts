from brownie import *
from config import *
import time

c = MainnetConfig()

deployer_acc = accounts.load(c.DEPLOYER)
para = ParaToken.at(c.PARA_TOKEN)
factory = Contract.from_explorer(c.UNISWAP_V2_FACTORY)
router = Contract.from_explorer(c.UNISWAP_V2_ROUTER)

def get_opts(from_ = deployer_acc) -> dict:
    return {"from": from_,
            "gas_price": int(web3.eth.gasPrice*1.3)}

# test pairs
eth_pair  = ''
usdt_pair = ''

# send test tokens to the team
# para.mint('', Wei('10000 ether'), get_opts())


def init_uniswap_pool(tokenA: str, tokenB: str) -> str:
    tx = factory.createPair(tokenA, tokenB, get_opts())
    pair_addr = tx._events['PairCreated']['pair']
    return pair_addr


def main():
    para_usd = 0.0000
    btc_usd  = 13522.6
    eth_usd  = 390.1
    usdt_usd = 1

    #
    # PARA-ETH
    #
    pool_amount = 100  # total USD liquidity
    para_amount = (pool_amount / 2) / para_usd
    eth_amount  = (pool_amount / 2) / eth_usd
    print(pool_amount, para_amount, eth_amount)

    # prepare PARA token
    para_amount_wei = Wei(f'{para_amount} ether')
    para.mint(deployer_acc.address, para_amount_wei, get_opts())
    para.approve(router.address, 0, get_opts())
    para.approve(router.address, para_amount_wei, get_opts())

    # prepare WETH (manually, since solidity version is too old)
    # weth = Contract.from_explorer(c.WETH_TOKEN)
    # or just use addLiquidityETH
    eth_amount_wei = Wei(f'{eth_amount} ether')
    deadline = int(time.time()) + 3600
    router.addLiquidityETH(
        c.PARA_TOKEN,
        para_amount_wei,
        para_amount_wei,
        eth_amount_wei,
        deployer_acc.address,
        deadline,
        {**get_opts(), 'amount': eth_amount_wei}
    )

    #
    # PARA-USDT
    #
    pool_amount = 100  # total USD liquidity
    para_amount = (pool_amount / 2) / para_usd
    usdt_amount = (pool_amount / 2) / usdt_usd
    print(pool_amount, para_amount, usdt_amount)

    # prepare PARA token
    para_amount_wei = Wei(f'{para_amount} ether')
    para.mint(deployer_acc.address, para_amount_wei, get_opts())
    para.approve(router.address, 0, get_opts())
    para.approve(router.address, para_amount_wei, get_opts())

    # prepare USDT (manually, old solidity)

    # add liquidity
    usdt_amount_wei = Wei(f'{usdt_amount} ether')
    deadline = int(time.time()) + 3600
    router.addLiquidity(
        c.PARA_TOKEN,
        c.USDT_TOKEN,
        para_amount_wei,
        usdt_amount_wei,
        para_amount_wei,
        usdt_amount_wei,
        deployer_acc.address,
        deadline,
        get_opts()
    )


    # pair_addr = init_uniswap_pool(c.PARA_TOKEN, c.WBTC_TOKEN)
    # pair_addr = init_uniswap_pool(c.PARA_TOKEN, c.USDT_TOKEN)
    # pair_addr = init_uniswap_pool(c.PARA_TOKEN, c.WETH_TOKEN)
    # pair_addr = '0x05aEb0ae4e5af3bAC40A2061C4B17fbDdD1a2F37'
    # pair = Contract.from_explorer(pair_addr)
    pass
