// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { KipuBank } from "./KipuBank.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.mock.sol";
import { MockERC20 } from "./mocks/MockERC20.mock.sol";
import { Test } from "forge-std/Test.sol";

contract KipuBankTest is Test {
    uint256 private constant BANK_CAP = 300;
    uint256 private constant MAX_SINGLE_WITHDRAW_LIMIT = 100;
    address private owner = address(this);

    MockAggregatorV3 private mockedFeed = new MockAggregatorV3();
    MockERC20 private mockedUsdcToken = new MockERC20();

    address private constant ETH_ADDRESS = address(0);
    address private usdcAddress = address(mockedUsdcToken);
    int256 private constant ETH_FACTOR = 1e8;
    int256 private constant MOCKED_ETH_PRICE = 2 * ETH_FACTOR;

    KipuBank private bank;

    receive() external payable {}

    function setUp() public {
        mockedFeed.setLatestRoundData(MOCKED_ETH_PRICE, block.timestamp);
        mockedUsdcToken.setBalance(address(this), 1000);

        bank = new KipuBank(BANK_CAP, MAX_SINGLE_WITHDRAW_LIMIT, owner, address(mockedFeed), mockedUsdcToken);
    }

    function test_ConstructorShouldRevertIfPreconditionsNotMet() public {
        vm.expectPartialRevert(KipuBank.ConstructorPreconditionError.selector);
        bank = new KipuBank(50, 100, owner, address(mockedFeed), mockedUsdcToken);
    }

    function test_GetMyFundsShouldReturnUserFundsInEth() public {
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 0, "My funds should be initialized at 0.");

        bank.depositEther{ value: 10 }();
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 10, "My funds should be updated after deposit.");

        bank.withdrawEther(5);
        vm.assertEq(bank.getMyFunds(ETH_ADDRESS), 5, "My funds should be updated after withdraw.");
    }

    function test_GetMyFundsShouldReturnUserFundsInUsdc() public {
        vm.assertEq(bank.getMyFunds(usdcAddress), 0, "My funds should be initialized at 0.");

        bank.depositUsdc(10);
        vm.assertEq(bank.getMyFunds(usdcAddress), 10, "My funds should be updated after deposit.");

        bank.withdrawUsdc(5);
        vm.assertEq(bank.getMyFunds(usdcAddress), 5, "My funds should be updated after withdraw.");
    }

    function test_GetDepositCountShouldStartAtZero() public {
        vm.assertEq(bank.getDepositCount(), 0, "Deposit count should start at 0.");
    }

    function test_GetWithdrawCountShouldStartAtZero() public {
        vm.assertEq(bank.getWithdrawCount(), 0, "Withdraw count should start at 0.");
    }

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

    function test_DepositUsdcShouldRevertIfBankCapReached() public {
        vm.expectPartialRevert(KipuBank.BankCapReachedError.selector);
        bank.depositUsdc((BANK_CAP + 1) * uint256(MOCKED_ETH_PRICE));
    }

    function test_DepositUsdcShouldUpdateValues() public {
        address addr = address(this);
        uint amount = 25;

        vm.assertEq(bank.getFundsForAddress(addr, usdcAddress), 0, "Funds should start at 0.");
        vm.assertEq(bank.getBalanceUsdc(), 0, "Bank should start at 0.");
        vm.assertEq(bank.getDepositCount(), 0, "Deposit count should start at 0.");

        bank.depositUsdc(amount);

        vm.assertEq(bank.getFundsForAddress(addr, usdcAddress), amount, "Funds should be updated.");
        vm.assertEq(bank.getBalanceUsdc(), amount, "Bank should be updated.");
        vm.assertEq(bank.getDepositCount(), 1, "Deposit count be at 1.");
    }

    function test_DepositUsdcShouldTransfer() public {
        address addr = address(this);
        uint amount = 25;
        uint initialBalance = mockedUsdcToken.balanceOf(addr);

        bank.depositUsdc(amount);

        vm.assertEq(mockedUsdcToken.balanceOf(addr), initialBalance - amount, "Funds should be updated.");
    }

    function test_DepositUsdcShouldEmitSuccess() public {
        vm.expectEmit();
        emit KipuBank.DepositSuccess(address(this), usdcAddress, 1);

        bank.depositUsdc(1);
    }

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

    function test_WithdrawEtherShouldEmitSuccess() public {
        bank.depositEther{ value: 10 }();

        vm.expectEmit();
        emit KipuBank.WithdrawSuccess(address(this), ETH_ADDRESS, 5);

        bank.withdrawEther(5);
    }

    function test_WithdrawUsdcShouldRevertIfAmountExceedsLimit() public {
        vm.expectPartialRevert(KipuBank.WithdrawLimitExceededError.selector);
        bank.withdrawUsdc((MAX_SINGLE_WITHDRAW_LIMIT + 1) * uint256(MOCKED_ETH_PRICE));
    }

    function test_WithdrawUsdcShouldRevertIfAmountExceedsFunds() public {
        vm.expectPartialRevert(KipuBank.InsufficientFundsError.selector);
        bank.withdrawUsdc(10);
    }

    function test_WithdrawUsdcShouldUpdateValues() public {
        address addr = address(this);
        uint initialAmount = 25;
        uint withdrawnAmount = 10;

        bank.depositUsdc(initialAmount);

        vm.assertEq(bank.getFundsForAddress(addr, usdcAddress), initialAmount, "Funds should start at initial amount.");
        vm.assertEq(bank.getBalanceUsdc(), initialAmount, "Bank should start at initial amount.");
        vm.assertEq(bank.getWithdrawCount(), 0, "Withdraw count should start at 0.");

        bank.withdrawUsdc(withdrawnAmount);

        vm.assertEq(
            bank.getFundsForAddress(addr, usdcAddress),
            initialAmount - withdrawnAmount,
            "Funds should be updated."
        );
        vm.assertEq(bank.getBalanceUsdc(), initialAmount - withdrawnAmount, "Bank should be updated.");
        vm.assertEq(bank.getWithdrawCount(), 1, "Withdraw count should be at 1.");
    }

    function test_WithdrawUsdcShouldTransfer() public {
        address addr = address(this);
        uint amount = 25;
        uint initialBalance = mockedUsdcToken.balanceOf(addr);

        bank.depositUsdc(amount);
        vm.assertEq(mockedUsdcToken.balanceOf(addr), initialBalance - amount, "Funds should be updated.");

        bank.withdrawUsdc(amount);
        vm.assertEq(mockedUsdcToken.balanceOf(addr), initialBalance, "Funds should be updated.");
    }

    function test_WithdrawUsdcShouldEmitSuccess() public {
        bank.depositUsdc(10);
        bank.withdrawUsdc(5);

        vm.expectEmit();
        emit KipuBank.WithdrawSuccess(address(this), usdcAddress, 5);

        bank.withdrawUsdc(5);
    }

    function test_GetBalanceEtherShouldReturnInitialZero() public {
        vm.assertEq(bank.getBalanceEther(), 0, "Initial bank balance should be 0.");
    }

    function test_GetBalanceEtherShouldReturnCorrectBalance() public {
        bank.depositEther{ value: 10 }();
        vm.assertEq(bank.getBalanceEther(), 10, "Bank balance should be updated after deposit.");
    }

    function test_GetBalanceUsdcShouldReturnInitialBalance() public {
        uint256 initialBalance = mockedUsdcToken.balanceOf(address(bank));
        vm.assertEq(
            bank.getBalanceUsdc(),
            initialBalance,
            "Initial bank balance should be initial balance in ERC20 token."
        );
    }

    function test_GetBalanceUsdcShouldReturnCorrectBalance() public {
        uint256 initialBalance = mockedUsdcToken.balanceOf(address(bank));

        bank.depositUsdc(10);
        vm.assertEq(bank.getBalanceUsdc(), initialBalance + 10, "Bank balance should be updated after deposit.");
    }

    function test_GetTotalBalanceUsdShouldReturnInitialBalance() public {
        uint256 initialUsdcBalance = mockedUsdcToken.balanceOf(address(bank));
        vm.assertEq(
            bank.getTotalBalanceUsd(),
            initialUsdcBalance,
            "Initial total balance should be initial USDC balance."
        );
    }

    function test_GetTotalBalanceUsdShouldReturnCorrectBalance() public {
        uint256 initialUsdcBalance = mockedUsdcToken.balanceOf(address(bank));
        uint256 usdcAmount = 10;
        uint256 ethAmount = 5;

        bank.depositUsdc(usdcAmount);
        bank.depositEther{ value: ethAmount }();

        uint256 expectedUsdcBalance = initialUsdcBalance + usdcAmount;
        uint256 expectedEthBalanceInUsd = (ethAmount * uint256(MOCKED_ETH_PRICE)) / uint256(ETH_FACTOR);
        uint256 expectedBalance = expectedUsdcBalance + expectedEthBalanceInUsd;

        vm.assertEq(bank.getTotalBalanceUsd(), expectedBalance, "Total balance should include both USDC and ETH.");
    }
}
