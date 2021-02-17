import pandas as pd

from brownie import *

from config import Config

c = Config.get()
deployer_acc = c.get_deployer_account()


def mint(mint_csv_path: str):
    df = pd.read_csv(mint_csv_path)
    assert df.columns.tolist() == ["Address", "Amount"], "Invalid mint csv"

    para = ParaToken.at(c.PARA_TOKEN)
    assert deployer_acc.address == para.owner(), "Unauthorized account"

    output = "\nAddress,Amount,Txid\n"
    txids = []
    for _, row in df.iterrows():
        address = row["Address"]
        amount = int(row["Amount"])
        tx = para.mint(
            address,
            Wei(f"{amount} ether"),
            {
                "from": deployer_acc,
                "gas_price": int(web3.eth.gasPrice * c.GAS_MULTIPLIER),
            },
        )
        row = f"{address},{amount},{tx.txid}\n"
        print(row)
        output += row

    print(output)


def main():
    mint("~/Downloads/minting_template.csv")


if __name__ == "__main__":
    pass
