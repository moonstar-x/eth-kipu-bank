// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library KipuBankEvents {
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
}
