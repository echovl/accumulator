//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockToken is ERC20 {
    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol) {
    }  

    function mint(address account, uint amount) external {
        _mint(account, amount);
    }
}