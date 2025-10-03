// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Kipu Bank
 * @author Christian López (@moonstar-x)
 * @notice A smart contract for secure ETH deposits and withdrawals with bank cap and single withdrawal limit.
 * @dev Do not use in production. This is an educational example.
 */
contract KipuBank is ReentrancyGuard {
  /**
   * @notice The maximum value tha this contract can hold.
   */
  uint256 private immutable i_bankCap;

  /**
   * @notice The maximum amount that a user can withdraw from their vault in a single transaction.
   */
  uint256 private immutable i_maxSingleWithdrawLimit;

  /**
   * @notice Counter for each successful deposit.
   */
  uint256 private s_depositCount = 0;

  /**
   * @notice Counter for each successful withdrawal.
   */
  uint256 private s_withdrawCount = 0;

  /**
   * @notice Vault that keeps funds per address.
   */
  mapping(address => uint256) private s_vault;

  /**
   * @notice Event emitted when a deposit is successful.
   * @param _address The address of the message sender.
   * @param _amount The amount deposited.
   */
  event DepositSuccess(address _address, uint256 _amount);

  /**
   * @notice Event emitted when a withdraw is successful.
   * @param _address The address of the message sender.
   * @param _amount The amount withdrawn.
   */
  event WithdrawSuccess(address _address, uint256 _amount);

  /**
   * @notice Error thrown when the constructor preconditions are not met.
   * @param _reason The reason why the precondition failed.
   */
  error ConstructorPreconditionError(string _reason);

  /**
   * @notice Error thrown when the contract has or would reach the bank cap set in the deployment step by the current deposit.
   */
  error BankCapReachedError();

  /**
   * @notice Error thrown when the current withdrawal request would exceed the withdraw limit set in the deployment step.
   * @param _sender The address of the sender.
   * @param _amount The amount that was attempted to be withdrawn.
   */
  error WithdrawLimitExceededError(address _sender, uint256 _amount);

  /**
   * @notice Error thrown when a withdrawal request attempts to withdraw an amount that exceeds the funds stored in the contract.
   * @param _sender The address of the sender.
   * @param _funds The funds in the sender's vault.
   * @param _amount The amount that was attempted to be withdrawn.
   */
  error InsufficientFundsError(address _sender, uint256 _funds, uint256 _amount);

  /**
   * @notice Error thrown if a transfer was not successful.
   */
  error TransferError();

  /**
   * @notice Deploys the contract by setting the bank cap and the maximum single withdrawal limit.
   * @param _bankCap The maximum value that this contract can hold.
   * @param _maxWithdrawLimit The maximum amount that a user can withdraw from their vault in a single transaction.
   */
  constructor(uint256 _bankCap, uint256 _maxWithdrawLimit) {
    if (_bankCap < _maxWithdrawLimit) {
      revert ConstructorPreconditionError("Bank cap must be greater than max withdraw limit.");
    }

    i_bankCap = _bankCap;
    i_maxSingleWithdrawLimit = _maxWithdrawLimit;
  }

  /**
   * @notice Deposits the value in the address' vault.
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
   * @notice Withdraws amount from the address' vault.
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
   * @notice Get balance in this contract.
   */
  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }


  /**
   * @notice Get balance for the sender.
   */
  function getMyFunds() external view returns (uint256) {
    return s_vault[msg.sender];
  }

  /**
   * @notice Get funds stored in vault for a given address.
   * @param _address The address to check the funds for.
   */
  function getFundsForAddress(address _address) external view returns (uint256) {
    return s_vault[_address];
  }

  /**
   * @notice Get this contract's deposit count.
   */
  function getDepositCount() external view returns (uint256) {
    return s_depositCount;
  }

  /**
   * @notice Get this contract's withdraw count.
   */
  function getWithdrawCount() external view returns (uint256) {
    return s_withdrawCount;
  }

  /**
   * @notice Update the relevant variables when a deposit is successful.
   */
  function _updateDepositValues(address _address, uint256 _amount) private {
    s_vault[_address] += _amount;
    s_depositCount++;
  }

  /**
   * @notice Update the relevant variables when a withdrawal is successful.
   */
  function _updateWithdrawValues(address _address, uint256 _amount) private {
    s_vault[_address] -= _amount;
    s_withdrawCount++;
  }

  /**
   * @notice Allows contract to receive ETH directly.
   */
  receive() external payable {
    deposit();
  }
}
