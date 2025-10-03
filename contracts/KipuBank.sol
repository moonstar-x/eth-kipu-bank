// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Kipu Bank Interface
 * @author Christian López (@moonstar-x)
 * @notice The interface that KipuBank must implement.
 * @dev Used to document which functions are expected to be available in the contract.
 */
interface IKipuBank {
    /**
     * @notice Allows contract to receive ETH directly.
     */
    receive() external payable;

    /**
     * @notice Deposits the value in the address' vault.
     */
    function deposit() external payable;

    /**
     * @notice Withdraws amount from the address' vault.
     * @param _amount The amount to withdraw.
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice Get balance in this contract.
     * @return balance_ The balance of this contract.
     */
    function getBalance() external view returns (uint256 balance_);

    /**
     * @notice Get balance for the sender.
     * @return funds_ The balance of the sender.
     */
    function getMyFunds() external view returns (uint256 funds_);

    /**
     * @notice Get funds stored in vault for a given address.
     * @param _address The address to check the funds for.
     * @return funds_ The funds stored in vault for the given address.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getFundsForAddress(address _address) external view returns (uint256 funds_);

    /**
     * @notice Get this contract's deposit count.
     * @return depositCount_ The deposit count.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getDepositCount() external view returns (uint256 depositCount_);

    /**
     * @notice Get this contract's withdraw count.
     * @return withdrawCount_ The withdraw count.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getWithdrawCount() external view returns (uint256 withdrawCount_);
}

/**
 * @title Kipu Bank
 * @author Christian López (@moonstar-x)
 * @notice A smart contract for secure ETH deposits and withdrawals with bank cap and single withdrawal limit.
 * @dev Do not use in production. This is an educational example.
 */
contract KipuBank is IKipuBank, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice The address used to represent ETH in this contract.
     */
    address internal constant ETH_ADDRESS = address(0);

    /**
     * @notice The maximum value that this contract can hold.
     */
    uint256 private immutable i_bankCap;

    /**
     * @notice The maximum amount that a user can withdraw from their vault in a single transaction.
     */
    uint256 private immutable i_maxSingleWithdrawLimit;

    /**
     * @notice The USD Coin (USDC) token contract address on the Ethereum network.
     */
    IERC20 private immutable i_USDCToken;

    /**
     * @notice Counter for each successful deposit.
     */
    uint256 private s_depositCount = 0;

    /**
     * @notice Counter for each successful withdrawal.
     */
    uint256 private s_withdrawCount = 0;

    // TODO: This should store multiple tokens.
    /**
     * @notice Vault that keeps funds per address.
     */
    mapping(address _userAddress => uint256 _amount) private s_vault;

    /**
     * @notice Event emitted when a deposit is successful.
     * @param _address The address of the message sender.
     * @param _amount The amount deposited.
     */
    event DepositSuccess(address indexed _address, uint256 indexed _amount);

    /**
     * @notice Event emitted when a withdraw is successful.
     * @param _address The address of the message sender.
     * @param _amount The amount withdrawn.
     */
    event WithdrawSuccess(address indexed _address, uint256 indexed _amount);

    /**
     * @notice Error thrown when the constructor preconditions are not met.
     * @param _reason The reason why the precondition failed.
     */
    error ConstructorPreconditionError(string _reason);

    /**
     * @notice Error thrown when the contract has or would reach the bank cap set in
     * the deployment step by the current deposit.
     */
    error BankCapReachedError();

    /**
     * @notice Error thrown when the current withdrawal request would exceed the withdraw
     * limit set in the deployment step.
     * @param _sender The address of the sender.
     * @param _amount The amount that was attempted to be withdrawn.
     */
    error WithdrawLimitExceededError(address _sender, uint256 _amount);

    /**
     * @notice Error thrown when a withdrawal request attempts to withdraw an amount that
     * exceeds the funds stored in the contract.
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
     * @param _owner The address of the owner of the contract.
     * @param _usdcToken The address of the USD Coin (USDC) token contract on the Ethereum network.
     */
    constructor(uint256 _bankCap, uint256 _maxWithdrawLimit, address _owner, IERC20 _usdcToken) Ownable(_owner) {
        if (_bankCap < _maxWithdrawLimit) {
            revert ConstructorPreconditionError("Exp. bankCap >= maxWithdrawLimit");
        }

        i_bankCap = _bankCap;
        i_maxSingleWithdrawLimit = _maxWithdrawLimit;
        i_USDCToken = _usdcToken;
    }

    /**
     * @notice Allows contract to receive ETH directly.
     */
    receive() external payable override {
        deposit();
    }

    /**
     * @notice Get balance for the sender.
     * @return funds_ The balance of the sender.
     */
    function getMyFunds() external view override returns (uint256 funds_) {
        funds_ = s_vault[msg.sender];
    }

    /**
     * @notice Get funds stored in vault for a given address.
     * @param _address The address to check the funds for.
     * @return funds_ The funds stored in vault for the given address.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getFundsForAddress(address _address) external view onlyOwner override returns (uint256 funds_) {
        funds_ = s_vault[_address];
    }

    /**
     * @notice Get this contract's deposit count.
     * @return depositCount_ The deposit count.
     */
    function getDepositCount() external view onlyOwner override returns (uint256 depositCount_) {
        depositCount_ = s_depositCount;
    }

    /**
     * @notice Get this contract's withdraw count.
     * @return withdrawCount_ The withdraw count.
     */
    function getWithdrawCount() external view onlyOwner override returns (uint256 withdrawCount_) {
        withdrawCount_ = s_withdrawCount;
    }

    /**
     * @notice Deposits the value in the address' vault.
     */
    function deposit() public payable override {
        uint256 potentialBankValue = getBalance() + msg.value;
        if (potentialBankValue > i_bankCap) {
            revert BankCapReachedError();
        }

        _updateDepositValues(msg.sender, msg.value);
        emit DepositSuccess(msg.sender, msg.value);
    }

    // TODO: Implement deposit of other tokens.

    /**
     * @notice Withdraws amount from the address' vault.
     * @param _amount The amount to withdraw.
     */
    function withdraw(uint256 _amount) public override nonReentrant {
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

    // TODO: Implement conversion between ETH and USD.
    // TODO: Implement chainlink oracle price feed.

    /**
     * @notice Get balance in this contract.
     * @return balance_ The balance of this contract.
     */
    function getBalance() public view override returns (uint256 balance_) {
        balance_ = address(this).balance;
    }

    /**
     * @notice Update the relevant variables when a deposit is successful.
     * @param _address The address of the user making the deposit.
     * @param _amount The amount deposited.
     */
    function _updateDepositValues(address _address, uint256 _amount) private {
        s_vault[_address] += _amount;
        ++s_depositCount;
    }

    /**
     * @notice Update the relevant variables when a withdrawal is successful.
     * @param _address The address of the user making the withdrawal.
     * @param _amount The amount withdrawn.
     */
    function _updateWithdrawValues(address _address, uint256 _amount) private {
        s_vault[_address] -= _amount;
        ++s_withdrawCount;
    }
}
