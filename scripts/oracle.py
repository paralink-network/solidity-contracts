import base58

from brownie import *


def main():
    oracle = ParalinkOracle.deploy({"from": accounts[0]})

    oracle_user = OracleUserExample.deploy(oracle.address, {"from": accounts[1]})

    import json

    json.dump(
        oracle.abi,
        open(
            "/home/jure/workspace/sapientia/paralink/paralink-node/src/data/oracle_abi.json",
            "w",
        ),
    )


def request():
    ipfs_hash = "QmTUFeBdxkGJsvFeTthwrYNwfkNWkE4e5P5f8goPdLoLGc"
    ipfs_bytes32 = base58.b58decode(ipfs_hash)[2:]

    # oracle_user = OracleUserExample.at("0xe7CB1c67752cBb975a56815Af242ce2Ce63d3113")

    oracle_user = OracleUserExample.at("0xe4A49adA9e491174ed86Fc8157fc5735531F5CCB")

    tx = oracle_user.initiateRequest(
        ipfs_bytes32, 101, {"from": deployer_acc, "value": Wei("0.01 ether")}
    )

    raise
