// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev This mock ERC20 token is for testing purposes only, generated with AI.
 */
contract MockERC20 is IERC20 {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    uint256 public override totalSupply;

    bool public failTransfer;
    bool public failTransferFrom;

    function setBalance(address user, uint256 amount) external {
        balanceOf[user] = amount;
    }

    function setFailTransfer(bool fail) external {
        failTransfer = fail;
    }

    function setFailTransferFrom(bool fail) external {
        failTransferFrom = fail;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        if (failTransfer) return false;
        require(balanceOf[msg.sender] >= amount, "Insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (failTransferFrom) return false;
        require(balanceOf[from] >= amount, "Insufficient");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return true;
    }
}
