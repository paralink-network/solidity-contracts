// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "interfaces/IUniswapV2Router02.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/utils/Babylonian.sol";

pragma solidity ^0.6.12;

contract UniswapV2_ZapIn_General_V2 is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using Address for address;
    bool private stopped = false;
    uint16 public goodwill;
    address public dzgoodwillAddress;

    IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    IUniswapV1Factory public UniSwapV1FactoryAddress = IUniswapV1Factory(
        0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95
    );

    IUniswapV2Factory public UniSwapV2FactoryAddress = IUniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );

    address wethTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(
        uint16 _goodwill,
        address _dzgoodwillAddress
    ) public {
        goodwill = _goodwill;
        dzgoodwillAddress = _dzgoodwillAddress;
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
    @notice This function is used to invest in given Uniswap V2 pair through ETH/ERC20 Tokens
    @param _FromTokenContractAddress The ERC20 token used for investment (address(0x00) if ether)
    @param _ToUnipoolToken0 The Uniswap V2 pair token0 address
    @param _ToUnipoolToken1 The Uniswap V2 pair token1 address
    @param _amount The amount of fromToken to invest
    @param _minPoolTokens Reverts if less tokens received than this
    @return Amount of LP bought
     */
    function ZapIn(
        address _FromTokenContractAddress,
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 _amount,
        uint _minPoolTokens
    ) public payable nonReentrant stopInEmergency returns (uint256) {
        uint256 toInvest;
        if (_FromTokenContractAddress == address(0)) {
            require(msg.value > 0, "Error: ETH not sent");
            toInvest = msg.value;
        } else {
            require(msg.value == 0, "Error: ETH sent");
            require(_amount > 0, "Error: Invalid ERC amount");
            TransferHelper.safeTransferFrom(
                _FromTokenContractAddress,
                msg.sender,
                address(this),
                _amount
            );
            toInvest = _amount;
        }

        uint256 LPBought = _performZapIn(
            _FromTokenContractAddress,
            _ToUnipoolToken0,
            _ToUnipoolToken1,
            toInvest
        );

        require(LPBought >= _minPoolTokens, "ERR: High Slippage");

        //get pair address
        address _ToUniPoolAddress = UniSwapV2FactoryAddress.getPair(
            _ToUnipoolToken0,
            _ToUnipoolToken1
        );

        //transfer goodwill
        uint256 goodwillPortion = _transferGoodwill(
            _ToUniPoolAddress,
            LPBought
        );

        TransferHelper.safeTransfer(
            _ToUniPoolAddress,
            msg.sender,
            SafeMath.sub(LPBought, goodwillPortion)
        );
        return SafeMath.sub(LPBought, goodwillPortion);
    }

    function _performZapIn(
        address _FromTokenContractAddress,
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 token0Bought;
        uint256 token1Bought;

        if (canSwapFromV2(_ToUnipoolToken0, _ToUnipoolToken1)) {
            (token0Bought, token1Bought) = exchangeTokensV2(
                _FromTokenContractAddress,
                _ToUnipoolToken0,
                _ToUnipoolToken1,
                _amount
            );
        } else if (
            canSwapFromV1(_ToUnipoolToken0, _ToUnipoolToken1, _amount, _amount)
        ) {
            (token0Bought, token1Bought) = exchangeTokensV1(
                _FromTokenContractAddress,
                _ToUnipoolToken0,
                _ToUnipoolToken1,
                _amount
            );
        }

        require(token0Bought > 0 && token1Bought > 0, "Could not exchange");

        TransferHelper.safeApprove(
            _ToUnipoolToken0,
            address(uniswapV2Router),
            token0Bought
        );

        TransferHelper.safeApprove(
            _ToUnipoolToken1,
            address(uniswapV2Router),
            token1Bought
        );

        (uint256 amountA, uint256 amountB, uint256 LP) = uniswapV2Router
            .addLiquidity(
            _ToUnipoolToken0,
            _ToUnipoolToken1,
            token0Bought,
            token1Bought,
            1,
            1,
            address(this),
            now + 60
        );

        uint256 residue;
        if (SafeMath.sub(token0Bought, amountA) > 0) {
            if (canSwapFromV2(_ToUnipoolToken0, _FromTokenContractAddress)) {
                residue = swapFromV2(
                    _ToUnipoolToken0,
                    _FromTokenContractAddress,
                    SafeMath.sub(token0Bought, amountA)
                );
            } else {
                TransferHelper.safeTransfer(
                    _ToUnipoolToken0,
                    msg.sender,
                    SafeMath.sub(token0Bought, amountA)
                );
            }
        }

        if (SafeMath.sub(token1Bought, amountB) > 0) {
            if (canSwapFromV2(_ToUnipoolToken1, _FromTokenContractAddress)) {
                residue += swapFromV2(
                    _ToUnipoolToken1,
                    _FromTokenContractAddress,
                    SafeMath.sub(token1Bought, amountB)
                );
            } else {
                TransferHelper.safeTransfer(
                    _ToUnipoolToken1,
                    msg.sender,
                    SafeMath.sub(token1Bought, amountB)
                );
            }
        }

        if (residue > 0) {
            TransferHelper.safeTransfer(
                _FromTokenContractAddress,
                msg.sender,
                residue
            );
        }
        
        return LP;
    }

    function exchangeTokensV1(
        address _FromTokenContractAddress,
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 _amount
    ) internal returns (uint256 token0Bought, uint256 token1Bought) {
        IUniswapV2Pair pair = IUniswapV2Pair(
            UniSwapV2FactoryAddress.getPair(_ToUnipoolToken0, _ToUnipoolToken1)
        );
        (uint256 res0, uint256 res1, ) = pair.getReserves();
        if (_FromTokenContractAddress == address(0)) {
            token0Bought = _eth2Token(_ToUnipoolToken0, _amount);
            uint256 amountToSwap = calculateSwapInAmount(res0, token0Bought);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = SafeMath.div(token0Bought, 2);
            token1Bought = _eth2Token(_ToUnipoolToken1, amountToSwap);
            token0Bought = SafeMath.sub(token0Bought, amountToSwap);
        } else {
            if (_ToUnipoolToken0 == _FromTokenContractAddress) {
                uint256 amountToSwap = calculateSwapInAmount(res0, _amount);
                //if no reserve or a new pair is created
                if (amountToSwap <= 0) amountToSwap = SafeMath.div(_amount, 2);
                token1Bought = _token2Token(
                    _FromTokenContractAddress,
                    address(this),
                    _ToUnipoolToken1,
                    amountToSwap
                );

                token0Bought = SafeMath.sub(_amount, amountToSwap);
            } else if (_ToUnipoolToken1 == _FromTokenContractAddress) {
                uint256 amountToSwap = calculateSwapInAmount(res1, _amount);
                //if no reserve or a new pair is created
                if (amountToSwap <= 0) amountToSwap = SafeMath.div(_amount, 2);
                token0Bought = _token2Token(
                    _FromTokenContractAddress,
                    address(this),
                    _ToUnipoolToken0,
                    amountToSwap
                );

                token1Bought = SafeMath.sub(_amount, amountToSwap);
            } else {
                token0Bought = _token2Token(
                    _FromTokenContractAddress,
                    address(this),
                    _ToUnipoolToken0,
                    _amount
                );
                uint256 amountToSwap = calculateSwapInAmount(
                    res0,
                    token0Bought
                );
                //if no reserve or a new pair is created
                if (amountToSwap <= 0) amountToSwap = SafeMath.div(_amount, 2);

                token1Bought = _token2Token(
                    _FromTokenContractAddress,
                    address(this),
                    _ToUnipoolToken1,
                    amountToSwap
                );
                token0Bought = SafeMath.sub(token0Bought, amountToSwap);
            }
        }
    }

    function exchangeTokensV2(
        address _FromTokenContractAddress,
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 _amount
    ) internal returns (uint256 token0Bought, uint256 token1Bought) {
        IUniswapV2Pair pair = IUniswapV2Pair(
            UniSwapV2FactoryAddress.getPair(_ToUnipoolToken0, _ToUnipoolToken1)
        );
        (uint256 res0, uint256 res1, ) = pair.getReserves();
        if (
            canSwapFromV2(_FromTokenContractAddress, _ToUnipoolToken0) &&
            canSwapFromV2(_ToUnipoolToken0, _ToUnipoolToken1)
        ) {
            token0Bought = swapFromV2(
                _FromTokenContractAddress,
                _ToUnipoolToken0,
                _amount
            );
            uint256 amountToSwap = calculateSwapInAmount(res0, token0Bought);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = SafeMath.div(token0Bought, 2);
            token1Bought = swapFromV2(
                _ToUnipoolToken0,
                _ToUnipoolToken1,
                amountToSwap
            );
            token0Bought = SafeMath.sub(token0Bought, amountToSwap);
        } else if (
            canSwapFromV2(_FromTokenContractAddress, _ToUnipoolToken1) &&
            canSwapFromV2(_ToUnipoolToken0, _ToUnipoolToken1)
        ) {
            token1Bought = swapFromV2(
                _FromTokenContractAddress,
                _ToUnipoolToken1,
                _amount
            );
            uint256 amountToSwap = calculateSwapInAmount(res1, token1Bought);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = SafeMath.div(token1Bought, 2);
            token0Bought = swapFromV2(
                _ToUnipoolToken1,
                _ToUnipoolToken0,
                amountToSwap
            );
            token1Bought = SafeMath.sub(token1Bought, amountToSwap);
        }
    }

    //checks if tokens can be exchanged with UniV1
    function canSwapFromV1(
        address _fromToken,
        address _toToken,
        uint256 fromAmount,
        uint256 toAmount
    ) public view returns (bool) {
        require(
            _fromToken != address(0) || _toToken != address(0),
            "Invalid Exchange values"
        );

        if (_fromToken == address(0)) {
            IUniswapExchange toExchange = IUniswapExchange(
                UniSwapV1FactoryAddress.getExchange(_toToken)
            );
            uint256 tokenBalance = IERC20(_toToken).balanceOf(
                address(toExchange)
            );
            uint256 ethBalance = address(toExchange).balance;
            if (tokenBalance > toAmount && ethBalance > fromAmount) return true;
        } else if (_toToken == address(0)) {
            IUniswapExchange fromExchange = IUniswapExchange(
                UniSwapV1FactoryAddress.getExchange(_fromToken)
            );
            uint256 tokenBalance = IERC20(_fromToken).balanceOf(
                address(fromExchange)
            );
            uint256 ethBalance = address(fromExchange).balance;
            if (tokenBalance > fromAmount && ethBalance > toAmount) return true;
        } else {
            IUniswapExchange toExchange = IUniswapExchange(
                UniSwapV1FactoryAddress.getExchange(_toToken)
            );
            IUniswapExchange fromExchange = IUniswapExchange(
                UniSwapV1FactoryAddress.getExchange(_fromToken)
            );
            uint256 balance1 = IERC20(_fromToken).balanceOf(
                address(fromExchange)
            );
            uint256 balance2 = IERC20(_toToken).balanceOf(address(toExchange));
            if (balance1 > fromAmount && balance2 > toAmount) return true;
        }
        return false;
    }

    //checks if tokens can be exchanged with UniV2
    function canSwapFromV2(address _fromToken, address _toToken)
        public
        view
        returns (bool)
    {
        require(
            _fromToken != address(0) || _toToken != address(0),
            "Invalid Exchange values"
        );

        if (_fromToken == _toToken) return true;

        if (_fromToken == address(0) || _fromToken == wethTokenAddress) {
            if (_toToken == wethTokenAddress || _toToken == address(0))
                return true;
            IUniswapV2Pair pair = IUniswapV2Pair(
                UniSwapV2FactoryAddress.getPair(_toToken, wethTokenAddress)
            );
            if (_haveReserve(pair)) return true;
        } else if (_toToken == address(0) || _toToken == wethTokenAddress) {
            if (_fromToken == wethTokenAddress || _fromToken == address(0))
                return true;
            IUniswapV2Pair pair = IUniswapV2Pair(
                UniSwapV2FactoryAddress.getPair(_fromToken, wethTokenAddress)
            );
            if (_haveReserve(pair)) return true;
        } else {
            IUniswapV2Pair pair1 = IUniswapV2Pair(
                UniSwapV2FactoryAddress.getPair(_fromToken, wethTokenAddress)
            );
            IUniswapV2Pair pair2 = IUniswapV2Pair(
                UniSwapV2FactoryAddress.getPair(_toToken, wethTokenAddress)
            );
            IUniswapV2Pair pair3 = IUniswapV2Pair(
                UniSwapV2FactoryAddress.getPair(_fromToken, _toToken)
            );
            if (_haveReserve(pair1) && _haveReserve(pair2)) return true;
            if (_haveReserve(pair3)) return true;
        }
        return false;
    }

    //checks if the UNI v2 contract have reserves to swap tokens
    function _haveReserve(IUniswapV2Pair pair) internal view returns (bool) {
        if (address(pair) != address(0)) {
            (uint256 res0, uint256 res1, ) = pair.getReserves();
            if (res0 > 0 && res1 > 0) {
                return true;
            }
        }
    }

    function calculateSwapInAmount(uint256 reserveIn, uint256 userIn)
        public
        pure
        returns (uint256)
    {
        return
            Babylonian
                .sqrt(
                reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))
            )
                .sub(reserveIn.mul(1997)) / 1994;
    }

    //swaps _fromToken for _toToken
    //for eth, address(0) otherwise ERC token address
    function swapFromV2(
        address _fromToken,
        address _toToken,
        uint256 amount
    ) internal returns (uint256) {
        require(
            _fromToken != address(0) || _toToken != address(0),
            "Invalid Exchange values"
        );
        if (_fromToken == _toToken) return amount;

        require(canSwapFromV2(_fromToken, _toToken), "Cannot be exchanged");
        require(amount > 0, "Invalid amount");

        if (_fromToken == address(0)) {
            if (_toToken == wethTokenAddress) {
                IWETH(wethTokenAddress).deposit.value(amount)();
                return amount;
            }
            address[] memory path = new address[](2);
            path[0] = wethTokenAddress;
            path[1] = _toToken;

            uint256[] memory amounts = uniswapV2Router
                .swapExactETHForTokens
                .value(amount)(0, path, address(this), now + 180);
            return amounts[1];
        } else if (_toToken == address(0)) {
            if (_fromToken == wethTokenAddress) {
                IWETH(wethTokenAddress).withdraw(amount);
                return amount;
            }
            address[] memory path = new address[](2);
            TransferHelper.safeApprove(
                _fromToken,
                address(uniswapV2Router),
                amount
            );
            path[0] = _fromToken;
            path[1] = wethTokenAddress;

            uint256[] memory amounts = uniswapV2Router.swapExactTokensForETH(
                amount,
                0,
                path,
                address(this),
                now + 180
            );
            return amounts[1];
        } else {
            TransferHelper.safeApprove(
                _fromToken,
                address(uniswapV2Router),
                amount
            );
            uint256 returnedAmount = _swapTokenToTokenV2(
                _fromToken,
                _toToken,
                amount
            );
            require(returnedAmount > 0, "Error in swap");
            return returnedAmount;
        }
    }

    //swaps 2 ERC tokens (UniV2)
    function _swapTokenToTokenV2(
        address _fromToken,
        address _toToken,
        uint256 amount
    ) internal returns (uint256) {
        IUniswapV2Pair pair1 = IUniswapV2Pair(
            UniSwapV2FactoryAddress.getPair(_fromToken, wethTokenAddress)
        );
        IUniswapV2Pair pair2 = IUniswapV2Pair(
            UniSwapV2FactoryAddress.getPair(_toToken, wethTokenAddress)
        );
        IUniswapV2Pair pair3 = IUniswapV2Pair(
            UniSwapV2FactoryAddress.getPair(_fromToken, _toToken)
        );

        uint256[] memory amounts;

        if (_haveReserve(pair3)) {
            address[] memory path = new address[](2);
            path[0] = _fromToken;
            path[1] = _toToken;

            amounts = uniswapV2Router.swapExactTokensForTokens(
                amount,
                0,
                path,
                address(this),
                now + 180
            );
            return amounts[1];
        } else if (_haveReserve(pair1) && _haveReserve(pair2)) {
            address[] memory path = new address[](3);
            path[0] = _fromToken;
            path[1] = wethTokenAddress;
            path[2] = _toToken;

            amounts = uniswapV2Router.swapExactTokensForTokens(
                amount,
                0,
                path,
                address(this),
                now + 180
            );
            return amounts[2];
        }
        return 0;
    }

    /**
    @notice This function is used to buy tokens from eth
    @param _tokenContractAddress Token address which we want to buy
    @param _amount The amount of eth we want to exchange
    @return tokenBought The quantity of token bought
     */
    function _eth2Token(
        address _tokenContractAddress,
        uint256 _amount
    ) internal returns (uint256 tokenBought) {
        IUniswapExchange FromUniSwapExchangeContractAddress = IUniswapExchange(
            UniSwapV1FactoryAddress.getExchange(_tokenContractAddress)
        );

        tokenBought = FromUniSwapExchangeContractAddress
            .ethToTokenSwapInput
            .value(_amount)(0, SafeMath.add(now, 300));
    }

    /**
    @notice This function is used to swap token with ETH
    @param _FromTokenContractAddress The token address to swap from
    @param tokens2Trade The quantity of tokens to swap
    @return ethBought The amount of eth bought
     */
    function _token2Eth(
        address _FromTokenContractAddress,
        uint256 tokens2Trade,
        address _toWhomToIssue
    ) internal returns (uint256 ethBought) {
        IUniswapExchange FromUniSwapExchangeContractAddress = IUniswapExchange(
            UniSwapV1FactoryAddress.getExchange(_FromTokenContractAddress)
        );

        TransferHelper.safeApprove(
            _FromTokenContractAddress,
            address(FromUniSwapExchangeContractAddress),
            tokens2Trade
        );

        ethBought = FromUniSwapExchangeContractAddress.tokenToEthTransferInput(
            tokens2Trade,
            0,
            SafeMath.add(now, 300),
            _toWhomToIssue
        );
        require(ethBought > 0, "Error in swapping Eth: 1");
    }

    /**
    @notice This function is used to swap tokens
    @param _FromTokenContractAddress The token address to swap from
    @param _ToWhomToIssue The address to transfer after swap
    @param _ToTokenContractAddress The token address to swap to
    @param tokens2Trade The quantity of tokens to swap
    @return tokenBought The amount of tokens returned after swap
     */
    function _token2Token(
        address _FromTokenContractAddress,
        address _ToWhomToIssue,
        address _ToTokenContractAddress,
        uint256 tokens2Trade
    ) internal returns (uint256 tokenBought) {
        IUniswapExchange FromUniSwapExchangeContractAddress = IUniswapExchange(
            UniSwapV1FactoryAddress.getExchange(_FromTokenContractAddress)
        );

        TransferHelper.safeApprove(
            _FromTokenContractAddress,
            address(FromUniSwapExchangeContractAddress),
            tokens2Trade
        );

        tokenBought = FromUniSwapExchangeContractAddress
            .tokenToTokenTransferInput(
            tokens2Trade,
            0,
            0,
            SafeMath.add(now, 300),
            _ToWhomToIssue,
            _ToTokenContractAddress
        );
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

        TransferHelper.safeTransfer(
            _tokenContractAddress,
            dzgoodwillAddress,
            goodwillPortion
        );
    }

    function set_new_goodwill(uint16 _new_goodwill) public onlyOwner {
        require(
            _new_goodwill >= 0 && _new_goodwill < 10000,
            "GoodWill Value not allowed"
        );
        goodwill = _new_goodwill;
    }

    function set_new_dzgoodwillAddress(address _new_dzgoodwillAddress)
        public
        onlyOwner
    {
        dzgoodwillAddress = _new_dzgoodwillAddress;
    }

    function inCaseTokengetsStuck(IERC20 _TokenAddress) public onlyOwner {
        uint256 qty = _TokenAddress.balanceOf(address(this));
        TransferHelper.safeTransfer(address(_TokenAddress), owner(), qty);
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
