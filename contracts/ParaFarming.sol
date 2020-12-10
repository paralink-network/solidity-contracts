// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ParaFarming is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of PARA
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accParaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accParaPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. PARA to distribute per block.
        uint256 lastRewardBlock;  // Last block number that PARA distribution occurs.
        uint256 accParaPerShare;  // Accumulated PARA per share, times 1e12. See below.
    }

    // The PARA TOKEN!
    IERC20 public para;
    // PARA tokens created per block.
    uint256 public paraPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when PARA mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event InsufficientFunds(address indexed user, uint256 indexed pid, uint256 missing);

    constructor(
        IERC20 _para,
        uint256 _paraPerBlock,
        uint256 _startBlock
    ) public {
        para = _para;
        paraPerBlock = _paraPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending PARA on frontend.
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accParaPerShare = pool.accParaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 paraReward = multiplier.mul(paraPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accParaPerShare = accParaPerShare.add(paraReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accParaPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function addPool(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner {
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accParaPerShare: 0
        }));
    }

    // Update the given pool's PARA allocation point. Can only be called by the owner.
    function setPool(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        require(totalAllocPoint > 0, "setPool: totalAllocPoint must not be 0");
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Change the per block rewards
    function setReward(uint256 _amount) public onlyOwner {
        paraPerBlock = _amount;
    }


    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 paraReward = multiplier.mul(paraPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        // the contract cannot mint new tokens - they have to be provided externally
        // para.mint(address(this), paraReward);
        pool.accParaPerShare = pool.accParaPerShare.add(paraReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to ParaFarming for PARA allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accParaPerShare).div(1e12).sub(user.rewardDebt);
            uint256 available = para.balanceOf(address(this));
            if(pending > 0) {
                require(pending <= available, 'deposit: insufficient funds to pay out rewards');
                para.transfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accParaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Deposit LP tokens to ParaFarming for PARA allocation.
    function depositFor(address beneficiary, uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][beneficiary];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accParaPerShare).div(1e12).sub(user.rewardDebt);
            uint256 available = para.balanceOf(address(this));
            if(pending > 0) {
                require(pending <= available, 'deposit: insufficient funds to pay out rewards');
                para.transfer(beneficiary, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accParaPerShare).div(1e12);
        emit Deposit(beneficiary, _pid, _amount);
    }

    // Withdraw LP tokens from ParaFarming.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accParaPerShare).div(1e12).sub(user.rewardDebt);
        uint256 available = para.balanceOf(address(this));
        // If the contract is empty the user will loose their rewards!!!
        // Make sure to monitor the contract to always have sufficient funds
        // as well as add a UI check.
        if(pending > 0) {
            if (pending <= available) {
                para.transfer(msg.sender, pending);
            } else {
                para.transfer(msg.sender, available);
                emit InsufficientFunds(msg.sender, _pid, pending.sub(available));
            }
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accParaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

}
