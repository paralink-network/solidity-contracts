import "interfaces/IBPool.sol";

pragma solidity ^0.6.12;

interface IBFactory {

    function isBPool(address b) external view returns (bool);
    function newBPool() external returns (IBPool);
}
