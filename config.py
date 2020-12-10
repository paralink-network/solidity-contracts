class Config:
    NULL_ADDRESS = "0x0000000000000000000000000000000000000000"
    GAS_MULTIPLIER = 1.3  # avoid stuck tx's due to median gas variance
    DEPLOYER = "paralink_deployer"  # brownie account id


class MainnetConfig(Config):
    # Deployments
    PARA_TOKEN = ""
    TIMELOCK = ""
    GOVERNOR = ""

    UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

