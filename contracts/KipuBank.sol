// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract KipuBank is ReentrancyGuard {
  /**
   * The maximum value tha this contract can hold.
   */
  uint256 private immutable i_bankCap;

  /**
   * The maximum amount that a user can withdraw from their vault in a single transaction.
   */
  uint256 private immutable i_maxSingleWithdrawLimit;

  /**
   * Counter for each successful deposit.
   */
  uint256 private s_depositCount = 0;

  /**
   * Counter for each successful withdrawal.
   */
  uint256 private s_withdrawCount = 0;

  /**
   * Vault that keeps funds per address.
   */
  mapping(address => uint256) private s_vault;

  /**
   * Event emitted when a deposit is successful.
   * @param addr The address of the message sender.
   * @param amount The amount deposited.
   */
  event DepositSuccess(address addr, uint256 amount);

  /**
   * Event emitted when a withdraw is successful.
   * @param addr The address of the message sender.
   * @param amount The amount withdrawn.
   */
  event WithdrawSuccess(address addr, uint256 amount);

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

  constructor(uint256 _bankCap, uint256 _maxWithdrawLimit) {
    require(_bankCap > _maxWithdrawLimit, "Bank cap must be greater than max withdraw limit.");

    i_bankCap = _bankCap;
    i_maxSingleWithdrawLimit = _maxWithdrawLimit;
  }

  /**
   * Deposits the value in the address' vault.
   */
  function deposit() public payable {
    uint256 potentialBankValue = getBalance() + msg.value;
    if (potentialBankValue > i_bankCap) {
      revert BankCapReachedError();
    }

    _updateDepositValues(msg.sender, msg.value);
    emit DepositSuccess(msg.sender, msg.value);
  }

  /**
   * Withdraws amount from the address' vault.
   * @param _amount The amount to withdraw. 
   */
  function withdraw(uint256 _amount) public nonReentrant {
    if (_amount > i_maxSingleWithdrawLimit) {
      revert WithdrawLimitExceededError(msg.sender, i_maxSingleWithdrawLimit);
    }

    uint256 funds = s_vault[msg.sender];
    if (_amount > funds) {
      revert InsufficientFundsError(msg.sender, funds, _amount);
    }

    _updateWithdrawValues(msg.sender, _amount);
    emit WithdrawSuccess(msg.sender, _amount);

    address payable payableSender = payable(msg.sender);
    (bool success, ) = payableSender.call{ value: _amount }("");
    if (!success) {
      revert TransferError();
    }
  }

  /**
   * Get balance in this contract.
   */
  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }


  /**
   * Get balance for the sender.
   */
  function getMyFunds() external view returns (uint256) {
    return s_vault[msg.sender];
  }

  /**
   * Get funds stored in vault for a given address.
   * @param _address The address to check the funds for.
   */
  function getFundsForAddress(address _address) external view returns (uint256) {
    return s_vault[_address];
  }

  /**
   * Get this contract's deposit count.
   */
  function getDepositCount() external view returns (uint256) {
    return s_depositCount;
  }

  /**
   * Get this contract's withdraw count.
   */
  function getWithdrawCount() external view returns (uint256) {
    return s_withdrawCount;
  }

  /**
   * Update the relevant variables when a deposit is successful.
   */
  function _updateDepositValues(address _address, uint256 _amount) private {
    s_vault[_address] += _amount;
    s_depositCount++;
  }

  /**
   * Update the relevant variables when a withdrawal is successful.
   */
  function _updateWithdrawValues(address _address, uint256 _amount) private {
    s_vault[_address] -= _amount;
    s_withdrawCount++;
  }

  receive() external payable {
    deposit();
  }
}
