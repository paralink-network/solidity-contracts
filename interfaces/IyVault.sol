// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IyVault {
    function deposit(uint256) external;

    function withdraw(uint256) external;

    function getPricePerFullShare() external view returns (uint256);

    function token() external view returns (address);

    function balanceOf(address whom) external view returns (uint);
    function approve(address dst, uint amt) external returns (bool);
}

interface ICurveZapInGeneral {
    function ZapIn(
        address _toWhomToIssue,
        address _IncomingTokenAddress,
        address _curvePoolExchangeAddress,
        uint256 _IncomingTokenQty,
        uint256 _minPoolTokens
    ) external payable returns (uint256 crvTokensBought);
}

interface ICurveZapOutGeneral {
    function ZapOut(
        address payable _toWhomToIssue,
        address _curveExchangeAddress,
        uint256 _tokenCount,
        uint256 _IncomingCRV,
        address _ToTokenAddress,
        uint256 _minToTokens
    ) external returns (uint256 ToTokensBought);
}

interface IAaveLendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address payable);
}

interface IAaveLendingPool {
    function deposit(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external payable;
}

interface IAToken {
    function redeem(uint256 _amount) external;

    function underlyingAssetAddress() external returns (address);
}
