// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library KipuBankErrors {
  /**
   * Error thrown when the contract has or would reach the bank cap set
   * in the deployment step by the current deposit.
   */
  error BankCapReachedError();

  /**
   * Error thrown when the current withdrawal request would exceed the
   * withdraw limit set in the deployment step.
   * @param sender The address of the sender.
   * @param amount The amount that was attempted to be withdrawn.
   */
  error WithdrawLimitExceededError(address sender, uint256 amount);

  /**
   * Error thrown when a withdrawal request attempts to withdraw an amount
   * that exceeds the funds stored in the contract.
   * @param sender The address of the sender.
   * @param funds The funds in the sender's vault.
   * @param amount The amount that was attempted to be withdrawn.
   */
  error InsufficientFundsError(address sender, uint256 funds, uint256 amount);

  /**
   * Error thrown if a transfer was not successful.
   */
  error TransferError();
}
