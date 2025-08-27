// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { KipuBank } from "./KipuBank.sol";
import { KipuBankErrors } from "./errors/KipuBankErrors.sol";
import { KipuBankEvents } from "./events/KipuBankEvents.sol";
import { Test } from "forge-std/Test.sol";

contract KipuBankTest is Test {
  uint256 private constant BANK_CAP = 300;
  uint256 private constant MAX_SINGLE_WITHDRAW_LIMIT = 100;

  KipuBank bank;

  function setUp() public {
    bank = new KipuBank(BANK_CAP, MAX_SINGLE_WITHDRAW_LIMIT);
  }

  function test_DepositShouldRevertIfBankCapReached() public {
    vm.expectRevert(KipuBankErrors.BankCapReachedError.selector);
    bank.deposit{ value: BANK_CAP + 1 }();
  }

  function test_DepositShouldUpdateValues() public {
    address addr = address(this);
    uint amount = 25;

    vm.assertEq(bank.getFundsForAddress(addr), 0, "Funds should start at 0.");
    vm.assertEq(bank.getBalance(), 0, "Bank should start at 0.");
    vm.assertEq(bank.getDepositCount(), 0, "Deposit count should start at 0.");

    bank.deposit{ value: amount }();

    vm.assertEq(bank.getFundsForAddress(addr), amount, "Funds should be updated.");
    vm.assertEq(bank.getBalance(), amount, "Bank should be updated.");
    vm.assertEq(bank.getDepositCount(), 1, "Deposit count be at 1.");
  }

  function test_DepositShouldEmitSuccess() public {
    vm.expectEmit();
    emit KipuBankEvents.DepositSuccess(address(this), 1);

    bank.deposit{ value: 1 }();
  }

  function test_WithdrawShouldRevertIfAmountExceedsLimit() public {
    vm.expectPartialRevert(KipuBankErrors.WithdrawLimitExceededError.selector);
    bank.withdraw(MAX_SINGLE_WITHDRAW_LIMIT + 1);
  }

  function test_WithdrawShouldRevertIfAmountExceedsFunds() public {
    vm.expectPartialRevert(KipuBankErrors.InsufficientFundsError.selector);
    bank.withdraw(10);
  }

  function test_WithdrawShouldTransferAmountToSender() public {
    vm.expectCall(address(bank), abi.encodeCall(bank.withdraw, (5)));
    bank.deposit{ value: 10 }();
    bank.withdraw(5);
  }

  function test_WithdrawShouldUpdateValues() public {
    address addr = address(this);
    uint initialAmount = 25;
    uint withdrawnAmount = 10;

    vm.expectCall(address(bank), abi.encodeCall(bank.withdraw, (withdrawnAmount)));

    bank.deposit{ value: initialAmount }();

    vm.assertEq(bank.getFundsForAddress(addr), initialAmount, "Funds should start at initial amount.");
    vm.assertEq(bank.getBalance(), initialAmount, "Bank should start at initial amount.");
    vm.assertEq(bank.getWithdrawCount(), 0, "Withdraw count should start at 0.");

    bank.withdraw(withdrawnAmount);

    vm.assertEq(bank.getFundsForAddress(addr), initialAmount - withdrawnAmount, "Funds should be updated.");
    vm.assertEq(bank.getBalance(), initialAmount - withdrawnAmount, "Bank should be updated.");
    vm.assertEq(bank.getWithdrawCount(), 1, "Withdraw count should be at 1.");
  }

  function test_WithdrawShouldEmitSuccess() public {
    bank.deposit{ value: 10 }();

    vm.expectEmit();
    emit KipuBankEvents.WithdrawSuccess(address(this), 5);

    bank.withdraw(5);
  }

  function test_GetMyFundsShouldReturnUserFunds() public {
    vm.assertEq(bank.getMyFunds(), 0, "My funds should initialized at 0.");

    bank.deposit{ value: 10 }();
    vm.assertEq(bank.getMyFunds(), 10, "My funds should be updated after deposit.");

    bank.withdraw(5);
    vm.assertEq(bank.getMyFunds(), 5, "My funds should be updated after withdraw.");
  }

  receive() external payable {

  }
}
