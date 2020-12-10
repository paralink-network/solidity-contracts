// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract ParaStaking is ERC20("Para Staking Shares", "sPARA"){
    using SafeMath for uint256;
    IERC20 public para;

    constructor(IERC20 para) public {
        para = para;
    }

    function stake(uint256 _amount) public {
        uint256 totalPara = para.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalPara == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalPara);
            _mint(msg.sender, what);
        }
        para.transferFrom(msg.sender, address(this), _amount);
    }

    function unstake(uint256 _amount) public {
        uint256 totalShares = totalSupply();
        uint256 give = _amount.mul(para.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _amount);
        para.transfer(msg.sender, give);
    }
}
