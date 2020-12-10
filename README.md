![](https://paralink.network/images/logo-sm-home.png)

# Paralink Solidity Contracts

## Set up local environment

### Dependencies

Install `ganache` and `truffle` clis:

```
npm install -g ganache-cli truffle truffle-flattener
```

You need python dev package, the below command works for Ubuntu:

```
sudo apt install libpython3.8-dev
```

Install `pipenv` environment:

```
pipenv sync
```

Install [Metamask](https://metamask.io/download.html).

## Run

1. Start ethereum node, we assume it is running on `localhost:8546`. If you do not possess such power, connect with the SSH to our global node:

   ```
   ssh <server_ip> -N -L 8546:localhost:8546
   ```

2.  Run `ganache-cli` forking the Mainnet:

    ```
    ganache-cli --fork ws://localhost:8546 --port 8600
    ```

3. Set the brownie network to forked node:

   ```
   pipenv run brownie networks modify mainnet-fork explorer=https://api.etherscan.io/api port=8600 fork=ws://localhost:8546
   ```

4. Setup Metamask to use the forked node. Under network selection -> Custom RPC, use `http://localhost:8600` as the host. In `ganache-cli` we should be seeing occasional requests if everything is setup correctly.

5.  Compile contracts

    ```
    pipenv run brownie compile
    ```

    After the first run, it will recompile automatically, whenever the brownie is restarted.

6. Deploy the contract on your local node

   ```
   pipenv run brownie run deploy_local.py
   ```

   See the deployed contract address in the `brownie` or in `ganache-cli` terminal.

### Create persistent `ganache-cli`

The following command saves the chain between the runs and ensures deterministic behaviour:

```
ganache-cli --accounts 10 --hardfork istanbul --fork ws://localhost:8546 --gasLimit 12000000 --mnemonic brownie --port 8600 -i 1 -d --db .ganache_db
```

The data is saved into `.ganache_db` directory. Pair it up with an archival node to have your own fork.

## Tests

To run all the tests:

```
pipenv run brownie test
```


## Deployment
First we need to import the Deployer account (will be prompted to enter private key):
```
pipenv run brownie accounts new paralink_deployer
```

If not already, set `WEB3_INFURA_PROJECT_ID` in `.env`.

### Deploy the token

```
pipenv run brownie run deploy/0_token.py --network mainnet
```

## Generate the Etherscan Contract Verification codes

For each deployed contract, a `truffle-flattener` must run, ie:

```
truffle-flattener contracts/ParaToken.sol > etherscan.sol
```
The code of the flattener output needs to be modified to:
 - remove duplicate SPDX-License identifiers

To generate constructor ABI-encoded parameters, get the abi:
```
cat build/contracts/ParaToken.json | jq .abi
```

Then use this tool to encode it:
https://abi.hashex.org/
