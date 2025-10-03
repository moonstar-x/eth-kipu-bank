// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { KipuBankErrors } from "./errors/KipuBankErrors.sol";
import { KipuBankEvents } from "./events/KipuBankEvents.sol";
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
      revert KipuBankErrors.BankCapReachedError();
    }

    _updateDepositValues(msg.sender, msg.value);
    emit KipuBankEvents.DepositSuccess(msg.sender, msg.value);
  }

  /**
   * Withdraws amount from the address' vault.
   * @param _amount The amount to withdraw. 
   */
  function withdraw(uint256 _amount) public nonReentrant {
    if (_amount > i_maxSingleWithdrawLimit) {
      revert KipuBankErrors.WithdrawLimitExceededError(msg.sender, i_maxSingleWithdrawLimit);
    }

    uint256 funds = s_vault[msg.sender];
    if (_amount > funds) {
      revert KipuBankErrors.InsufficientFundsError(msg.sender, funds, _amount);
    }

    _updateWithdrawValues(msg.sender, _amount);
    emit KipuBankEvents.WithdrawSuccess(msg.sender, _amount);

    address payable payableSender = payable(msg.sender);
    (bool success, ) = payableSender.call{ value: _amount }("");
    if (!success) {
      revert KipuBankErrors.TransferError();
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
