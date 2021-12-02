//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IMasterChef {
    function deposit(uint pid, uint amount) external;
    function withdraw(uint pid, uint amount) external;
    function userInfo(uint pid, address user) external view returns (uint);
}

contract Accumulator is Ownable {
    using SafeERC20 for IERC20;

    struct Share {
        uint pairBalance;
        uint profit;
    }

    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    IMasterChef public masterchef;
    IUniswapRouter public router;
    IERC20 public lpToken;
    IERC20 public farmToken;
    uint public poolId;
    uint public accRewardPerShare;
    uint public lastRewardTime;

    IERC20 public rewardToken;
    address[] public path;

    mapping(address => UserInfo) userInfo;

    constructor(
        address _masterchef,
        address _router,
        address _farmToken,
        address _lpToken,
        uint _poolId,
        address[] memory _path
    ) {
        masterchef = IMasterChef(_masterchef);
        router = IUniswapRouter(_router);
        farmToken = IERC20(_farmToken);
        lpToken = IERC20(_lpToken);
        poolId = _poolId;
        path = _path;
        rewardToken = IERC20(path[path.length - 1]);
        lastRewardTime = block.timestamp;
        accRewardPerShare = 0;

        _giveAllowances();
    }

    /**
     * @dev Deposit `amount` lp tokens to the balance.
     */
    function deposit(uint amount) external {
        require(lpToken.balanceOf(msg.sender) >= amount, "Not enough funds");

        UserInfo storage user = userInfo[msg.sender];

        updateRewardDistribution();

        uint pending = (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare / 1e12);

        if (pending > 0) {
            rewardToken.safeTransfer(msg.sender, pending);
        }

        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        uint _balance = lpToken.balanceOf(address(this));
        masterchef.deposit(poolId, _balance);
    }

    /**
     * @dev Withdraws user's lp tokens and reward.
     */
    function withdraw(uint amount) external {
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount >= amount);

        updateRewardDistribution();

        uint lpBalance = lpToken.balanceOf(address(this));
        uint pending = (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare / 1e12);

        if (lpBalance < amount) {
            masterchef.withdraw(poolId, amount - lpBalance);
        }

        if (pending > 0) {
            rewardToken.safeTransfer(msg.sender, pending);
        }

        lpToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Updates reward distribution variables.
     */
    function updateRewardDistribution() public {
        uint lpBalance = lpToken.balanceOf(address(this)) 
            + masterchef.userInfo(poolId, address(this));

        if (lpBalance == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        
        uint rewardBefore = rewardToken.balanceOf(address(this));
        _harvest();
        uint reward = rewardToken.balanceOf(address(this)) - rewardBefore;

        accRewardPerShare += (reward * 1e12) / lpBalance;
        lastRewardTime = block.timestamp;
    }

    function balance(address user) public view returns (uint) {
        return userInfo[user].amount;
    }

    function pendingRewards(address _user) public view returns (uint) {
        UserInfo storage user = userInfo[_user];
        return (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
    }

    /**
     * @dev Collects rewards and swap them for the target token. 
     */
    function _harvest() internal {
        masterchef.deposit(poolId, 0);
        uint _balance = farmToken.balanceOf(address(this));
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_balance, 0, path, address(this), block.timestamp);
    }

    function _giveAllowances() internal {
        lpToken.safeApprove(address(masterchef), type(uint).max);
        farmToken.safeApprove(address(router), type(uint).max);
    }
}
