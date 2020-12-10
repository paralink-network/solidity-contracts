run:
	ssh ethnode_hetzner_rublix -N -L 8546:localhost:8546
	ganache-cli --fork ws://localhost:8546 --port 8600

setup-networks:
	pipenv run brownie networks modify mainnet-fork explorer=https://api.etherscan.io/api port=8600 fork=ws://localhost:8546
	pipenv run brownie networks add development ropsten-fork host=http://127.0.0.1 cmd=ganache-cli port=8600 fork=ws://localhost:8646
	pipenv run brownie networks modify ropsten-fork explorer=https://api-ropsten.etherscan.io/api
