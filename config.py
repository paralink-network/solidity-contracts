class Config:
    NULL_ADDRESS = "0x0000000000000000000000000000000000000000"
    GAS_MULTIPLIER = 1.5  # avoid stuck tx's due to median gas variance
    DEPLOYER_ETH = "paralink_deployer_eth"  # brownie account id
    DEPLOYER_BSC = "paralink_deployer_bsc"  # brownie account id


class MainnetConfig(Config):
    # Deployments
    PARA_TOKEN = "0x3a8d5BC8A8948b68DfC0Ce9C14aC4150e083518c"
    PARA_FARMING = ""
    PARA_STAKING = ""
    TIMELOCK = ""
    GOVERNOR = ""

    UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"


class BinanceTestnet(Config):
    PARA_ORACLE = "0xf1DBf560bB5a2b0150DBaF3Fc351Be969A2CD7b0"
    PARA_ORACLE_USER = "0xe4A49adA9e491174ed86Fc8157fc5735531F5CCB"

