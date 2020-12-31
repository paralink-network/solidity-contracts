import base58

from brownie import *


def main():
    oracle = ParalinkOracle.deploy({"from": accounts[0]})


def create_request():
    oracle = ParalinkOracle.at("0x3194cBDC3dbcd3E11a07892e7bA5c3394048Cc87")
    ipfs_hash = "QmTUFeBdxkGJsvFeTthwrYNwfkNWkE4e5P5f8goPdLoLGc"

    ipfs_bytes32 = ipfs_to_bytes32(ipfs_hash)

    tx = oracle.request(
        ipfs_bytes32, accounts[1], oracle.address, 0, 1, "", {"from": accounts[1]}
    )


def ipfs_to_bytes32(hash_str: str):
    """Convert IPFS hash to bytes32 type."""
    bytes_array = base58.b58decode(hash_str)
    return bytes_array[2:]
