//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Accumulator.sol";
import "./MockToken.sol";

contract MockUniswapV2Router is IUniswapRouter {
    using SafeERC20 for IERC20;

    address public token0;
    address public token1;
    // token0 = token1 * ratio
    uint public ratio;

    constructor(address _token0, address _token1, uint _ratio) {
        token0 = _token0;
        token1 = _token1;
        ratio = _ratio;
    }

    // This router need to hold some balance of token0 and token1 for swaps
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override {
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(tokenIn == token0 || tokenIn == token1);
        require(tokenOut == token0 || tokenOut == token1);
        require(tokenIn != tokenOut);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        if (tokenIn == token0) {
            MockToken(tokenOut).mint(to, amountIn * ratio);
        } else {
            MockToken(tokenOut).mint(to, amountIn / ratio);
        }
    }
}