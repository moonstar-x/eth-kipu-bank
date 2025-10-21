// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";

/**
 * @dev This mock ERC20 token is for testing purposes only, generated with AI.
 */
contract MockPermit2 is IPermit2 {
event PermitUsed(address owner, address token, uint256 amount);
    event TransferFromCalled(address token, address from, address to, uint256 amount);

    mapping(address => mapping(address => uint256)) public allowance;

    function permit(
        address owner,
        address token,
        uint160 amount,
        uint48 /* expiration */,
        uint48 /* nonce */,
        bytes calldata /* signature */
    ) external {
        allowance[owner][token] = amount;
        emit PermitUsed(owner, token, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external {
        require(allowance[from][token] >= amount, "MockPermit2: insufficient allowance");
        allowance[from][token] -= amount;
        IERC20(token).transferFrom(from, to, amount);
        emit TransferFromCalled(token, from, to, amount);
    }
}
