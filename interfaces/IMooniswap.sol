import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.6.12;

interface IMooniswap {
    function swap(address src, address dst, uint256 amount, uint256 minReturn, address referral) external payable returns(uint256 result);
    function deposit(uint256[] calldata amounts, uint256[] calldata minAmounts) external payable returns(uint256 fairSupply);
    function withdraw(uint256 amount, uint256[] memory minReturns) external;

    function getTokens() external view returns(IERC20[] memory);

    function balanceOf(address whom) external view returns (uint);
    function getReturn(IERC20 src, IERC20 dst, uint256 amount) external view returns(uint256);

    function totalSupply() external view returns (uint256);
}
