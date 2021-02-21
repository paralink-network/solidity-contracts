![](https://paralink.network/images/logo-sm-home.png)

# Paralink Solidity Contracts

### Dependencies

Install `ganache` and `truffle` clis:

```
npm install -g ganache-cli truffle
```

Install python 3.8 dev package

Ubuntu 20.04:

```
sudo apt install libpython3.8-dev
```

Macos:

```
brew install python@3.8
brew link --overwrite python@3.8
```

Install `pipenv` environment:

```
pip3 install -U pipenv
pipenv sync
```

### Ethereum

Setup the Etherscan and Infura api keys in a `.env` file:

```
ETHERSCAN_TOKEN=
WEB3_INFURA_PROJECT_ID=
```

To enable etherscan API in development, call the following command:

```
pipenv run brownie networks modify development explorer=https://api.etherscan.io/api
```

### Binance Smart Chain (BSC)

To add support for Binance Smart Chain, run:

```
pipenv run brownie networks add "Ethereum" "binance-mainnet" host="https://bsc-dataseed1.defibit.io/" chainid=56
```

## Compile contracts

Trigger manual re-compile:

```
pipenv run brownie compile
```

After the first run, it will recompile automatically, whenever the brownie is restarted.

## Get the ABI

After contracts are compiled the ABI's are available in `build` folder.

```
cat build/contracts/CONTRACT.json | jq .abi
```

## Deploy Locally

Start the local mainnet-fork and leave the console open:

```
pipenv run brownie console --network mainnet-fork
```

Deploy the contracts on your local node by typing this into the console:

```
run('deploy_local')
```

This will print newly **deployed contracts and their addresses**.

Leave the console open for the duration of the fork. If you need a fresh fork, repeat the above 2 steps.

## Tests

To run all the tests:

```
pipenv run brownie test
```


## Mainnet Deployment
First we need to import the Deployer accounts (will be prompted to enter private key):
```
pipenv run brownie accounts new paralink_deployer_eth
pipenv run brownie accounts new paralink_deployer_bsc
```

### Deploy a contract

```
pipenv run brownie run deploy/CONTRACT.py --network mainnet
pipenv run brownie run deploy/CONTRACT.py --network binance-mainnet
```
