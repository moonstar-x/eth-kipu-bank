// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { KipuBankErrors } from "./errors/KipuBankErrors.sol";
import { KipuBankEvents } from "./events/KipuBankEvents.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract KipuBank is ReentrancyGuard {
  /**
   * The maximum value tha this contract can hold.
   */
  uint256 private immutable BANK_CAP;

  /**
   * The maximum amount that a user can withdraw from their vault in a single transaction.
   */
  uint256 private immutable MAX_SINGLE_WITHDRAW_LIMIT;

  /**
   * Vault that keeps funds per address.
   */
  mapping(address => uint256) private _vault;

  /**
   * Value that tracks the entire amount stored in the contract.
   */
  uint256 private _bankValue = 0;

  /**
   * Counter for each successful deposit.
   */
  uint256 private _depositCount = 0;

  /**
   * Counter for each successful withdrawal.
   */
  uint256 private _withdrawCount = 0;

  constructor(uint256 bankCap, uint256 maxWithdrawLimit) {
    require(bankCap > maxWithdrawLimit, "Bank cap must be greater than max withdraw limit.");

    BANK_CAP = bankCap;
    MAX_SINGLE_WITHDRAW_LIMIT = maxWithdrawLimit;
  }

  /**
   * Deposits the value in the address' vault.
   */
  function deposit() public payable {
    uint256 potentialBankValue = _bankValue + msg.value;
    if (potentialBankValue > BANK_CAP) {
      revert KipuBankErrors.BankCapReachedError();
    }

    _updateDepositValues(msg.sender, msg.value);
    emit KipuBankEvents.DepositSuccess(msg.sender, msg.value);
  }

  /**
   * Withdraws amount from the address' vault.
   * @param amount The amount to withdraw. 
   */
  function withdraw(uint256 amount) public nonReentrant {
    if (amount > MAX_SINGLE_WITHDRAW_LIMIT) {
      revert KipuBankErrors.WithdrawLimitExceededError(msg.sender, MAX_SINGLE_WITHDRAW_LIMIT);
    }

    uint256 funds = _vault[msg.sender];
    if (amount > funds) {
      revert KipuBankErrors.InsufficientFundsError(msg.sender, funds, amount);
    }

    address payable payableSender = payable(msg.sender);
    (bool success, ) = payableSender.call{ value: amount }("");
    if (!success) {
      revert KipuBankErrors.TransferError();
    }

    _updateWithdrawValues(msg.sender, amount);
    emit KipuBankEvents.WithdrawSuccess(msg.sender, amount);
  }

  /**
   * Get funds stored in vault for a given address.
   * @param addr The address to check the funds for.
   */
  function getFundsForAddress(address addr) external view returns (uint256) {
    return _vault[addr];
  }

  /**
   * Get total value in this contract.
   */
  function getTotalValue() external view returns (uint256) {
    return _bankValue;
  }

  /**
   * Get this contract's deposit count.
   */
  function getDepositCount() external view returns (uint256) {
    return _depositCount;
  }

  /**
   * Get this contract's withdraw count.
   */
  function getWithdrawCount() external view returns (uint256) {
    return _withdrawCount;
  }

  /**
   * Update the relevant variables when a deposit is successful.
   */
  function _updateDepositValues(address addr, uint256 amount) private {
    _vault[addr] += amount;
    _bankValue += amount;
    _depositCount++;
  }

  /**
   * Update the relevant variables when a withdrawal is successful.
   */
  function _updateWithdrawValues(address addr, uint256 amount) private {
    _vault[addr] -= amount;
    _bankValue -= amount;
    _withdrawCount++;
  }
}
