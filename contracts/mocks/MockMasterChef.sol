//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Accumulator.sol";
import "./MockToken.sol";

contract MockMasterChef is IMasterChef {
    using SafeERC20 for IERC20;

    IERC20 public lpToken;
    MockToken public rewardToken;
    uint public fixedReward;

    mapping(address => uint) balance;

    constructor(
        address _lpToken,
        address _rewardToken,
        uint _fixedReward
    ) {
        lpToken = IERC20(_lpToken);
        rewardToken = MockToken(_rewardToken);
        fixedReward = _fixedReward;
    }

    function deposit(uint pid, uint amount) external override {
        // Only transfer rewards on harvests to simulate a linear distribution.
        if (amount == 0) {
            rewardToken.mint(msg.sender, fixedReward);
        }

        balance[msg.sender] += amount;
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint pid, uint amount) external override {
        rewardToken.mint(msg.sender, fixedReward);
        balance[msg.sender] -= amount;
        lpToken.safeTransfer(msg.sender, amount);
    }

    function userInfo(uint pid, address user) external view override returns (uint) {
        return balance[user];
    }
}