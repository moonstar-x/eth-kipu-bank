// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { KipuBank } from "./KipuBank.sol";
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KipuBankTest is Test {
    uint256 private constant BANK_CAP = 300;
    uint256 private constant MAX_SINGLE_WITHDRAW_LIMIT = 100;
    address private owner = address(this);
    address private priceFeed = address(this);
    address private constant ETH_ADDRESS = address(0);
    IERC20 private constant USDC_TOKEN = IERC20(address(0));

    KipuBank bank;

    receive() external payable {}

    function setUp() public {
        bank = new KipuBank(BANK_CAP, MAX_SINGLE_WITHDRAW_LIMIT, owner, priceFeed, USDC_TOKEN);
    }

    function test_ConstructorShouldRevertIfPreconditionsNotMet() public {
        vm.expectPartialRevert(KipuBank.ConstructorPreconditionError.selector);
        bank = new KipuBank(50, 100, owner, priceFeed, USDC_TOKEN);
    }

    function test_GetMyFundsShouldReturnUserFunds() public {
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 0, "My funds should initialized at 0.");

        bank.depositEther{ value: 10 }();
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 10, "My funds should be updated after deposit.");

        bank.withdrawEther(5);
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 5, "My funds should be updated after withdraw.");
    }

    // TODO: Test getMyFunds returns correct funds for USDC.

    // TODO: Test getFundsForAddress returns correct funds for ETH.
    // TODO: Test getFundsForAddress returns correct funds for USDC.

    // TODO: Test getDepositCount returns correct count.

    // TODO: Test getWithdrawCount returns correct count.

    function test_DepositEtherShouldRevertIfBankCapReached() public {
        vm.expectPartialRevert(KipuBank.BankCapReachedError.selector);
        bank.depositEther{ value: BANK_CAP + 1 }();
    }

    function test_DepositEtherShouldUpdateValues() public {
        address addr = address(this);
        uint amount = 25;

        vm.assertEq(bank.getFundsForAddress(addr, ETH_ADDRESS), 0, "Funds should start at 0.");
        vm.assertEq(bank.getBalanceEther(), 0, "Bank should start at 0.");
        vm.assertEq(bank.getDepositCount(), 0, "Deposit count should start at 0.");

        bank.depositEther{ value: amount }();

        vm.assertEq(bank.getFundsForAddress(addr, ETH_ADDRESS), amount, "Funds should be updated.");
        vm.assertEq(bank.getBalanceEther(), amount, "Bank should be updated.");
        vm.assertEq(bank.getDepositCount(), 1, "Deposit count be at 1.");
    }

    function test_DepositEtherShouldEmitSuccess() public {
        vm.expectEmit();
        emit KipuBank.DepositSuccess(address(this), ETH_ADDRESS, 1);

        bank.depositEther{ value: 1 }();
    }

    // TODO: Test depositUsdc should revert if bank cap reached.
    // TODO: Test depositUsdc should update values.
    // TODO: Test depositUsdc should transfer.
    // TODO: Test depositUsdc should emit success.

    function test_WithdrawEtherShouldRevertIfAmountExceedsLimit() public {
        vm.expectPartialRevert(KipuBank.WithdrawLimitExceededError.selector);
        bank.withdrawEther(MAX_SINGLE_WITHDRAW_LIMIT + 1);
    }

    function test_WithdrawEtherShouldRevertIfAmountExceedsFunds() public {
        vm.expectPartialRevert(KipuBank.InsufficientFundsError.selector);
        bank.withdrawEther(10);
    }

    function test_WithdrawEtherShouldUpdateValues() public {
        address addr = address(this);
        uint initialAmount = 25;
        uint withdrawnAmount = 10;

        vm.expectCall(address(bank), abi.encodeCall(bank.withdrawEther, (withdrawnAmount)));

        bank.depositEther{ value: initialAmount }();

        vm.assertEq(bank.getFundsForAddress(addr, ETH_ADDRESS), initialAmount, "Funds should start at initial amount.");
        vm.assertEq(bank.getBalanceEther(), initialAmount, "Bank should start at initial amount.");
        vm.assertEq(bank.getWithdrawCount(), 0, "Withdraw count should start at 0.");

        bank.withdrawEther(withdrawnAmount);

        vm.assertEq(
            bank.getFundsForAddress(addr, ETH_ADDRESS),
            initialAmount - withdrawnAmount,
            "Funds should be updated."
        );
        vm.assertEq(bank.getBalanceEther(), initialAmount - withdrawnAmount, "Bank should be updated.");
        vm.assertEq(bank.getWithdrawCount(), 1, "Withdraw count should be at 1.");
    }

    function test_WithdrawEtherShouldTransferAmountToSender() public {
        vm.expectCall(address(bank), abi.encodeCall(bank.withdrawEther, (5)));
        bank.depositEther{ value: 10 }();
        bank.withdrawEther(5);
    }

    // TODO: Test withdrawEther should revert if transfer fails.

    function test_WithdrawEtherShouldEmitSuccess() public {
        bank.depositEther{ value: 10 }();

        vm.expectEmit();
        emit KipuBank.WithdrawSuccess(address(this), ETH_ADDRESS, 5);

        bank.withdrawEther(5);
    }

    // TODO: Test withdrawUsdc should revert if amount exceeds limit.
    // TODO: Test withdrawUsdc should revert if insufficient funds.
    // TODO: Test withdrawUsdc should update values.
    // TODO: Test withdrawUsdc should transfer.
    // TODO: Test withdrawUsdc should emit success.

    // TODO: Test getBalanceEther should return correct balance.

    // TODO: Test getBalanceUsd should return correct balance.
}
