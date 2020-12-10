/**
 *Submitted for verification at Etherscan.io on 2020-07-30
*/

// ███████╗░█████╗░██████╗░██████╗░███████╗██████╗░░░░███████╗██╗
// ╚════██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗░░░██╔════╝██║
// ░░███╔═╝███████║██████╔╝██████╔╝█████╗░░██████╔╝░░░█████╗░░██║
// ██╔══╝░░██╔══██║██╔═══╝░██╔═══╝░██╔══╝░░██╔══██╗░░░██╔══╝░░██║
// ███████╗██║░░██║██║░░░░░██║░░░░░███████╗██║░░██║██╗██║░░░░░██║
// ╚══════╝╚═╝░░╚═╝╚═╝░░░░░╚═╝░░░░░╚══════╝╚═╝░░╚═╝╚═╝╚═╝░░░░░╚═╝
// Copyright (C) 2020 zapper, dipeshsukhani, nodarjanashia, suhailg, sebaudet, sumitrajput, apoorvlathey

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//

///@author Zapper
///@notice this contract adds liquidity to Balancer liquidity pools in one transaction

// File: @openzeppelin/contracts/utils/Address.sol

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "interfaces/IUniswapV2Router02.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "contracts/utils/Babylonian.sol";

pragma solidity ^0.6.12;


interface IBFactory {
function isBPool(address b) external view returns (bool);
}

interface IBPool {
    function joinswapExternAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        uint256 minPoolAmountOut
    ) external payable returns (uint256 poolAmountOut);

    function isBound(address t) external view returns (bool);

    function getFinalTokens() external view returns (address[] memory tokens);

    function totalSupply() external view returns (uint256);

    function getDenormalizedWeight(address token)
        external
        view
        returns (uint256);

    function getTotalDenormalizedWeight() external view returns (uint256);

    function getSwapFee() external view returns (uint256);

    function calcPoolOutGivenSingleIn(
        uint256 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint256 poolSupply,
        uint256 totalWeight,
        uint256 tokenAmountIn,
        uint256 swapFee
    ) external pure returns (uint256 poolAmountOut);

    function getBalance(address token) external view returns (uint256);
    function balanceOf(address whom) external view returns (uint);
    function allowance(address src, address dst) external view returns (uint);

    function approve(address dst, uint amt) external returns (bool);
    function transfer(address dst, uint amt) external returns (bool);
    function transferFrom(
        address src, address dst, uint amt
    ) external returns (bool);
}


contract Balancer_ZapIn_General_V2_6 is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    bool public stopped = false;
    uint16 public goodwill;

    IBFactory BalancerFactory = IBFactory(
        0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd
    );
    IUniswapV2Factory
        private constant UniSwapV2FactoryAddress = IUniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );
    IUniswapV2Router02 private constant uniswapRouter = IUniswapV2Router02(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    address
        private constant wethTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address payable
        public zgoodwillAddress = 0xE737b6AfEC2320f616297e59445b60a11e3eF75F;

    uint256
        private constant deadline = 0xf000000000000000000000000000000000000000000000000000000000000000;

    event zap(
        address zapContract,
        address userAddress,
        address tokenAddress,
        uint256 volume,
        uint256 timestamp
    );

    constructor(uint16 _goodwill) public {
        goodwill = _goodwill;
    }

    // circuit breaker modifiers
    modifier stopInEmergency {
        if (stopped) {
            revert("Temporarily Paused");
        } else {
            _;
        }
    }

    /**
    @notice This function is used to invest in given balancer pool through ETH/ERC20 Tokens
    @param _FromTokenContractAddress The token used for investment (address(0x00) if ether)
    @param _ToBalancerPoolAddress The address of balancer pool to zapin
    @param _amount The amount of ERC to invest
    @param _minPoolTokens for slippage
    @return tokensBought success or failure
    */
    function ZapIn(
        address _FromTokenContractAddress,
        address _ToBalancerPoolAddress,
        uint256 _amount,
        uint256 _minPoolTokens
    )
        public
        payable
        nonReentrant
        stopInEmergency
        returns (uint256 tokensBought)
    {
        require(
            BalancerFactory.isBPool(_ToBalancerPoolAddress),
            "Invalid Balancer Pool"
        );

        emit zap(
            address(this),
            msg.sender,
            _FromTokenContractAddress,
            _amount,
            now
        );

        if (_FromTokenContractAddress == address(0)) {
            require(msg.value > 0, "ERR: No ETH sent");

            //transfer eth to goodwill
            uint256 goodwillPortion = _transferGoodwill(address(0), msg.value);

            address _IntermediateToken = _getBestDeal(
                _ToBalancerPoolAddress,
                msg.value,
                _FromTokenContractAddress
            );

            tokensBought = _performZapIn(
                address(this),
                _FromTokenContractAddress,
                _ToBalancerPoolAddress,
                msg.value.sub(goodwillPortion),
                _IntermediateToken,
                _minPoolTokens
            );

            return tokensBought;
        }

        require(_amount > 0, "ERR: No ERC sent");
        require(msg.value == 0, "ERR: ETH sent with tokens");

        //transfer tokens to contract
        IERC20(_FromTokenContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        //send tokens to goodwill
        uint256 goodwillPortion = _transferGoodwill(
            _FromTokenContractAddress,
            _amount
        );

        address _IntermediateToken = _getBestDeal(
            _ToBalancerPoolAddress,
            _amount,
            _FromTokenContractAddress
        );

        tokensBought = _performZapIn(
            address(this),
            _FromTokenContractAddress,
            _ToBalancerPoolAddress,
            _amount.sub(goodwillPortion),
            _IntermediateToken,
            _minPoolTokens
        );

        return tokensBought;
    }

    /**
    @notice This function internally called by ZapIn() and EasyZapIn()
    @param _toWhomToIssue The user address who want to invest
    @param _FromTokenContractAddress The token used for investment (address(0x00) if ether)
    @param _ToBalancerPoolAddress The address of balancer pool to zapin
    @param _amount The amount of ETH/ERC to invest
    @param _IntermediateToken The token for intermediate conversion before zapin
    @param _minPoolTokens for slippage
    @return tokensBought The quantity of Balancer Pool tokens returned
    */
    function _performZapIn(
        address _toWhomToIssue,
        address _FromTokenContractAddress,
        address _ToBalancerPoolAddress,
        uint256 _amount,
        address _IntermediateToken,
        uint256 _minPoolTokens
    ) internal returns (uint256 tokensBought) {
        // check if isBound()
        bool isBound = IBPool(_ToBalancerPoolAddress).isBound(
            _FromTokenContractAddress
        );

        uint256 balancerTokens;

        if (isBound) {
            balancerTokens = _enter2Balancer(
                _ToBalancerPoolAddress,
                _FromTokenContractAddress,
                _amount,
                _minPoolTokens
            );
        } else {
            // swap tokens or eth
            uint256 tokenBought;
            if (_FromTokenContractAddress == address(0)) {
                tokenBought = _eth2Token(_amount, _IntermediateToken);
            } else {
                tokenBought = _token2Token(
                    _FromTokenContractAddress,
                    _IntermediateToken,
                    _amount
                );
            }

            //get BPT
            balancerTokens = _enter2Balancer(
                _ToBalancerPoolAddress,
                _IntermediateToken,
                tokenBought,
                _minPoolTokens
            );
        }

        //transfer tokens to user
        IERC20(_ToBalancerPoolAddress).safeTransfer(
            _toWhomToIssue,
            balancerTokens
        );
        return balancerTokens;
    }

    /**
    @notice This function is used to zapin to balancer pool
    @param _ToBalancerPoolAddress The address of balancer pool to zap in
    @param _FromTokenContractAddress The token used to zap in
    @param tokens2Trade The amount of tokens to invest
    @return poolTokensOut The quantity of Balancer Pool tokens returned
    */
    function _enter2Balancer(
        address _ToBalancerPoolAddress,
        address _FromTokenContractAddress,
        uint256 tokens2Trade,
        uint256 _minPoolTokens
    ) internal returns (uint256 poolTokensOut) {
        require(
            IBPool(_ToBalancerPoolAddress).isBound(_FromTokenContractAddress),
            "Token not bound"
        );

        uint256 allowance = IERC20(_FromTokenContractAddress).allowance(
            address(this),
            _ToBalancerPoolAddress
        );

        if (allowance < tokens2Trade) {
            IERC20(_FromTokenContractAddress).safeApprove(
                _ToBalancerPoolAddress,
                uint256(-1)
            );
        }

        poolTokensOut = IBPool(_ToBalancerPoolAddress).joinswapExternAmountIn(
            _FromTokenContractAddress,
            tokens2Trade,
            _minPoolTokens
        );

        require(poolTokensOut > 0, "Error in entering balancer pool");
    }

    /**
    @notice This function finds best token from the final tokens of balancer pool
    @param _ToBalancerPoolAddress The address of balancer pool to zap in
    @param _amount amount of eth/erc to invest
    @param _FromTokenContractAddress the token address which is used to invest
    @return _token The token address having max liquidity
    */
    function _getBestDeal(
        address _ToBalancerPoolAddress,
        uint256 _amount,
        address _FromTokenContractAddress
    ) internal view returns (address _token) {
        // If input is not eth or weth
        if (
            _FromTokenContractAddress != address(0) &&
            _FromTokenContractAddress != wethTokenAddress
        ) {
            // check if input token or weth is bound and if so return it as intermediate
            bool isBound = IBPool(_ToBalancerPoolAddress).isBound(
                _FromTokenContractAddress
            );
            if (isBound) return _FromTokenContractAddress;
        }

        bool wethIsBound = IBPool(_ToBalancerPoolAddress).isBound(
            wethTokenAddress
        );
        if (wethIsBound) return wethTokenAddress;

        //get token list
        address[] memory tokens = IBPool(_ToBalancerPoolAddress)
            .getFinalTokens();

        uint256 amount = _amount;
        address[] memory path = new address[](2);

        if (
            _FromTokenContractAddress != address(0) &&
            _FromTokenContractAddress != wethTokenAddress
        ) {
            path[0] = _FromTokenContractAddress;
            path[1] = wethTokenAddress;
            //get eth value for given token
            amount = uniswapRouter.getAmountsOut(_amount, path)[1];
        }

        uint256 maxBPT;
        path[0] = wethTokenAddress;

        for (uint256 index = 0; index < tokens.length; index++) {
            uint256 expectedBPT;

            if (tokens[index] != wethTokenAddress) {
                if (
                    UniSwapV2FactoryAddress.getPair(
                        tokens[index],
                        wethTokenAddress
                    ) == address(0)
                ) {
                    continue;
                }

                //get qty of tokens
                path[1] = tokens[index];
                uint256 expectedTokens = uniswapRouter.getAmountsOut(
                    amount,
                    path
                )[1];

                //get bpt for given tokens
                expectedBPT = getToken2BPT(
                    _ToBalancerPoolAddress,
                    expectedTokens,
                    tokens[index]
                );

                //get token giving max BPT
                if (maxBPT < expectedBPT) {
                    maxBPT = expectedBPT;
                    _token = tokens[index];
                }
            } else {
                //get bpt for given weth tokens
                expectedBPT = getToken2BPT(
                    _ToBalancerPoolAddress,
                    amount,
                    tokens[index]
                );
            }

            //get token giving max BPT
            if (maxBPT < expectedBPT) {
                maxBPT = expectedBPT;
                _token = tokens[index];
            }
        }
    }

    /**
    @notice Function gives the expected amount of pool tokens on investing
    @param _ToBalancerPoolAddress Address of balancer pool to zapin
    @param _IncomingERC The amount of ERC to invest
    @param _FromToken Address of token to zap in with
    @return tokensReturned Amount of BPT token
    */
    function getToken2BPT(
        address _ToBalancerPoolAddress,
        uint256 _IncomingERC,
        address _FromToken
    ) internal view returns (uint256 tokensReturned) {
        uint256 totalSupply = IBPool(_ToBalancerPoolAddress).totalSupply();
        uint256 swapFee = IBPool(_ToBalancerPoolAddress).getSwapFee();
        uint256 totalWeight = IBPool(_ToBalancerPoolAddress)
            .getTotalDenormalizedWeight();
        uint256 balance = IBPool(_ToBalancerPoolAddress).getBalance(_FromToken);
        uint256 denorm = IBPool(_ToBalancerPoolAddress).getDenormalizedWeight(
            _FromToken
        );

        tokensReturned = IBPool(_ToBalancerPoolAddress)
            .calcPoolOutGivenSingleIn(
            balance,
            denorm,
            totalSupply,
            totalWeight,
            _IncomingERC,
            swapFee
        );
    }

    /**
    @notice This function is used to buy tokens from eth
    @param _tokenContractAddress Token address which we want to buy
    @return tokenBought The quantity of token bought
    */

    function _eth2Token(uint256 _ethAmt, address _tokenContractAddress)
        internal
        returns (uint256 tokenBought)
    {
        if (_tokenContractAddress == wethTokenAddress) {
            IWETH(wethTokenAddress).deposit.value(_ethAmt)();
            return _ethAmt;
        }

        address[] memory path = new address[](2);
        path[0] = wethTokenAddress;
        path[1] = _tokenContractAddress;
        tokenBought = uniswapRouter.swapExactETHForTokens.value(_ethAmt)(
            1,
            path,
            address(this),
            deadline
        )[path.length - 1];
    }

    /**
    @notice This function is used to swap tokens
    @param _FromTokenContractAddress The token address to swap from
    @param _ToTokenContractAddress The token address to swap to
    @param tokens2Trade The amount of tokens to swap
    @return tokenBought The quantity of tokens bought
    */
    function _token2Token(
        address _FromTokenContractAddress,
        address _ToTokenContractAddress,
        uint256 tokens2Trade
    ) internal returns (uint256 tokenBought) {
        IERC20(_FromTokenContractAddress).safeApprove(
            address(uniswapRouter),
            tokens2Trade
        );

        if (_FromTokenContractAddress != wethTokenAddress) {
            if (_ToTokenContractAddress != wethTokenAddress) {
                address[] memory path = new address[](3);
                path[0] = _FromTokenContractAddress;
                path[1] = wethTokenAddress;
                path[2] = _ToTokenContractAddress;
                tokenBought = uniswapRouter.swapExactTokensForTokens(
                    tokens2Trade,
                    1,
                    path,
                    address(this),
                    deadline
                )[path.length - 1];
            } else {
                address[] memory path = new address[](2);
                path[0] = _FromTokenContractAddress;
                path[1] = wethTokenAddress;

                tokenBought = uniswapRouter.swapExactTokensForTokens(
                    tokens2Trade,
                    1,
                    path,
                    address(this),
                    deadline
                )[path.length - 1];
            }
        } else {
            address[] memory path = new address[](2);
            path[0] = wethTokenAddress;
            path[1] = _ToTokenContractAddress;
            tokenBought = uniswapRouter.swapExactTokensForTokens(
                tokens2Trade,
                1,
                path,
                address(this),
                deadline
            )[path.length - 1];
        }

        require(tokenBought > 0, "Error in swapping ERC: 1");
    }

    /**
    @notice This function is used to calculate and transfer goodwill
    @param _tokenContractAddress Token in which goodwill is deducted
    @param tokens2Trade The total amount of tokens to be zapped in
    @return goodwillPortion The quantity of goodwill deducted
    */

    function _transferGoodwill(
        address _tokenContractAddress,
        uint256 tokens2Trade
    ) internal returns (uint256 goodwillPortion) {
        goodwillPortion = SafeMath.div(
            SafeMath.mul(tokens2Trade, goodwill),
            10000
        );

        if (goodwillPortion == 0) {
            return 0;
        }

        if (_tokenContractAddress == address(0)) {
            Address.sendValue(zgoodwillAddress, goodwillPortion);
        } else {
            IERC20(_tokenContractAddress).safeTransfer(
                zgoodwillAddress,
                goodwillPortion
            );
        }
    }

    function set_new_goodwill(uint16 _new_goodwill) public onlyOwner {
        require(
            _new_goodwill >= 0 && _new_goodwill < 10000,
            "GoodWill Value not allowed"
        );
        goodwill = _new_goodwill;
    }

    function set_new_zgoodwillAddress(address payable _new_zgoodwillAddress)
        public
        onlyOwner
    {
        zgoodwillAddress = _new_zgoodwillAddress;
    }

    function inCaseTokengetsStuck(IERC20 _TokenAddress) public onlyOwner {
        uint256 qty = _TokenAddress.balanceOf(address(this));
        IERC20(address(_TokenAddress)).safeTransfer(owner(), qty);
    }

    // - to Pause the contract
    function toggleContractActive() public onlyOwner {
        stopped = !stopped;
    }

    // - to withdraw any ETH balance sitting in the contract
    function withdraw() public onlyOwner {
        uint256 contractBalance = address(this).balance;
        address payable _to = payable(owner());
        _to.transfer(contractBalance);
    }

    receive() external payable {}
}
