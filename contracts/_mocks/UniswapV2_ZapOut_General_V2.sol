// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "interfaces/IUniswapV2Router02.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.6.12;

contract UniswapV2_ZapOut_General_V2 is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using Address for address;
    bool private stopped = false;
    uint16 public goodwill;
    address public dzgoodwillAddress;

    IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    IUniswapV2Factory public UniSwapV2FactoryAddress = IUniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );

    address public wethTokenAddress = address(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

    constructor(uint16 _goodwill, address _dzgoodwillAddress) public {
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
    @notice This function is used to zapout of given Uniswap pair in the bounded tokens
    @param _FromUniPoolAddress The uniswap pair address to zapout
    @param _IncomingLP The amount of LP
    @return amountA the amount of first token received after zapout
    @return amountB the amount of second token received after zapout
     */
    function ZapOut2PairToken(
        address _FromUniPoolAddress,
        uint256 _IncomingLP
    )
        public
        payable
        nonReentrant
        stopInEmergency
        returns (uint256 amountA, uint256 amountB)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(_FromUniPoolAddress);

        require(address(pair) != address(0), "Error: Invalid Unipool Address");

        //get reserves
        address token0 = pair.token0();
        address token1 = pair.token1();

        TransferHelper.safeTransferFrom(
            _FromUniPoolAddress,
            msg.sender,
            address(this),
            _IncomingLP
        );

        uint256 goodwillPortion = _transferGoodwill(
            _FromUniPoolAddress,
            _IncomingLP
        );

        TransferHelper.safeApprove(
            _FromUniPoolAddress,
            address(uniswapV2Router),
            SafeMath.sub(_IncomingLP, goodwillPortion)
        );

        if (token0 == wethTokenAddress || token1 == wethTokenAddress) {
            address _token = token0 == wethTokenAddress ? token1 : token0;
            (amountA, amountB) = uniswapV2Router.removeLiquidityETH(
                _token,
                SafeMath.sub(_IncomingLP, goodwillPortion),
                1,
                1,
                msg.sender,
                now + 60
            );
        } else {
            (amountA, amountB) = uniswapV2Router.removeLiquidity(
                token0,
                token1,
                SafeMath.sub(_IncomingLP, goodwillPortion),
                1,
                1,
                msg.sender,
                now + 60
            );
        }
    }

    /**
    @notice This function is used to zapout of given Uniswap pair in ETH/ERC20 Tokens
    @param _ToTokenContractAddress The ERC20 token to zapout in (address(0x00) if ether)
    @param _FromUniPoolAddress The uniswap pair address to zapout from
    @param _IncomingLP The amount of LP
    @return the amount of eth/tokens received after zapout
     */
    function ZapOut(
        address _ToTokenContractAddress,
        address _FromUniPoolAddress,
        uint256 _IncomingLP,
        uint256 _minTokensRec
    ) public payable nonReentrant stopInEmergency returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(_FromUniPoolAddress);

        require(address(pair) != address(0), "Error: Invalid Unipool Address");

        //get pair tokens
        address token0 = pair.token0();
        address token1 = pair.token1();

        TransferHelper.safeTransferFrom(
            _FromUniPoolAddress,
            msg.sender,
            address(this),
            _IncomingLP
        );

        uint256 goodwillPortion = _transferGoodwill(
            _FromUniPoolAddress,
            _IncomingLP
        );

        TransferHelper.safeApprove(
            _FromUniPoolAddress,
            address(uniswapV2Router),
            SafeMath.sub(_IncomingLP, goodwillPortion)
        );

        (uint256 amountA, uint256 amountB) = uniswapV2Router.removeLiquidity(
            token0,
            token1,
            SafeMath.sub(_IncomingLP, goodwillPortion),
            1,
            1,
            address(this),
            now + 60
        );

        uint256 tokenBought;
        if (
            canSwapFromV2(_ToTokenContractAddress, token0) &&
            canSwapFromV2(_ToTokenContractAddress, token1)
        ) {
            tokenBought = swapFromV2(token0, _ToTokenContractAddress, amountA);
            tokenBought += swapFromV2(token1, _ToTokenContractAddress, amountB);
        } else if (canSwapFromV2(_ToTokenContractAddress, token0)) {
            uint256 token0Bought = swapFromV2(token1, token0, amountB);
            tokenBought = swapFromV2(
                token0,
                _ToTokenContractAddress,
                token0Bought.add(amountA)
            );
        } else if (canSwapFromV2(_ToTokenContractAddress, token1)) {
            uint256 token1Bought = swapFromV2(token0, token1, amountA);
            tokenBought = swapFromV2(
                token1,
                _ToTokenContractAddress,
                token1Bought.add(amountB)
            );
        }

        require(tokenBought >= _minTokensRec, "High slippage");

        if (_ToTokenContractAddress == address(0)) {
            msg.sender.transfer(tokenBought);
        } else {
            TransferHelper.safeTransfer(
                _ToTokenContractAddress,
                msg.sender,
                tokenBought
            );
        }

        return tokenBought;
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
            uint256 minTokens = uniswapV2Router.getAmountsOut(amount, path)[1];
            minTokens = SafeMath.div(
                SafeMath.mul(minTokens, SafeMath.sub(10000, 200)),
                10000
            );
            uint256[] memory amounts = uniswapV2Router
                .swapExactETHForTokens
                .value(amount)(minTokens, path, address(this), now + 180);
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
            uint256 minTokens = uniswapV2Router.getAmountsOut(amount, path)[1];
            minTokens = SafeMath.div(
                SafeMath.mul(minTokens, SafeMath.sub(10000, 200)),
                10000
            );
            uint256[] memory amounts = uniswapV2Router.swapExactTokensForETH(
                amount,
                minTokens,
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
            uint256 minTokens = uniswapV2Router.getAmountsOut(amount, path)[1];
            minTokens = SafeMath.div(
                SafeMath.mul(minTokens, SafeMath.sub(10000, 200)),
                10000
            );
            amounts = uniswapV2Router.swapExactTokensForTokens(
                amount,
                minTokens,
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
            uint256 minTokens = uniswapV2Router.getAmountsOut(amount, path)[2];
            minTokens = SafeMath.div(
                SafeMath.mul(minTokens, SafeMath.sub(10000, 200)),
                10000
            );
            amounts = uniswapV2Router.swapExactTokensForTokens(
                amount,
                minTokens,
                path,
                address(this),
                now + 180
            );
            return amounts[2];
        }
        return 0;
    }

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
            uint256 totalSupply = pair.totalSupply();
            if (totalSupply > 0) return true;
        }
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
        if (goodwill == 0) {
            return 0;
        }

        goodwillPortion = SafeMath.div(
            SafeMath.mul(tokens2Trade, goodwill),
            10000
        );

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


