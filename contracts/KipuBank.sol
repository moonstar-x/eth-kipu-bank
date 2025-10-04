// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
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
     * @notice Deposits the value in the address' ETH vault.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     */
    function depositEther() external payable;

    /**
     * @notice Deposits the value in the address' USDC vault.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     * @param _amount The amount in USDC to deposit.
     */
    function depositUsdc(uint256 _amount) external payable;

    /**
     * @notice Withdraws amount from the address' ETH vault.
     * @dev Reverts with WithdrawLimitExceededError if the amount exceeds the single withdraw limit.
     * @dev Reverts with InsufficientFundsError if the withdraw would exceed the available balance.
     * @dev Reverts with TransferError if the transfer was not successful.
     * @dev Emits a WithdrawSuccess event upon success.
     * @param _amount The amount to withdraw.
     */
    function withdrawEther(uint256 _amount) external;

    /**
     * @notice Withdraws the value in the address' USDC vault.
     * @dev Reverts with WithdrawLimitExceededError if the amount exceeds the single withdraw limit.
     * @dev Reverts with InsufficientFundsError if the withdraw would exceed the available balance.
     * @dev Reverts with TransferError if the transfer was not successful.
     * @dev Emits a WithdrawSuccess event upon success.
     * @param _amount The amount in USDC to withdraw.
     */
    function withdrawUsdc(uint256 _amount) external;

    /**
     * @notice Get balance in this contract in ETH.
     * @return balance_ The balance of this contract in ETH.
     */
    function getBalanceEther() external view returns (uint256 balance_);

    /**
     * @notice Get balance in this contract in USD.
     * @return balance_ The balance of this contract in USD.
     */
    function getBalanceUsd() external view returns (uint256 balance_);

    /**
     * @notice Get balance for the sender for a given token.
     * @param _token The token address to check the balance for (use address(0) for ETH).
     * @return funds_ The balance of the sender.
     */
    function getMyFunds(address _token) external view returns (uint256 funds_);

    /**
     * @notice Get funds stored in vault for a given address for a given token.
     * @param _address The address to check the funds for.
     * @param _token The token address to check the balance for (use address(0) for ETH).
     * @return funds_ The funds stored in vault for the given address.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getFundsForAddress(address _address, address _token) external view returns (uint256 funds_);

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
     * @notice The maximum age of a Chainlink oracle response before it is considered stale.
     */
    uint256 internal constant ORACLE_STALE_TIME_SECONDS = 3600;

    /**
     * @notice The factor to convert ETH price to USD.
     */
    uint256 internal constant ETH_DECIMAL_FACTOR = 1e20;

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
     * @notice The Chainlink price feed for ETH/USD.
     */
    AggregatorV3Interface private s_priceFeed;

    /**
     * @notice Counter for each successful deposit.
     */
    uint256 private s_depositCount = 0;

    /**
     * @notice Counter for each successful withdrawal.
     */
    uint256 private s_withdrawCount = 0;

    /**
     * @notice Vault that keeps funds per address per token.
     */
    mapping(address _userAddress => mapping(address _token => uint256 _amount)) private s_vault;

    /**
     * @notice Event emitted when a deposit is successful.
     * @param _address The address of the message sender.
     * @param _token The token address being deposited.
     * @param _amount The amount deposited.
     */
    event DepositSuccess(address indexed _address, address indexed _token, uint256 indexed _amount);

    /**
     * @notice Event emitted when a withdraw is successful.
     * @param _address The address of the message sender.
     * @param _token The token address being withdrawn.
     * @param _amount The amount withdrawn.
     */
    event WithdrawSuccess(address indexed _address, address indexed _token, uint256 indexed _amount);

    /**
     * @notice Error thrown when the constructor preconditions are not met.
     * @param _reason The reason why the precondition failed.
     */
    error ConstructorPreconditionError(string _reason);

    /**
     * @notice Error thrown when the contract has or would reach the bank cap set in
     * the deployment step by the current deposit.
     * @param _sender The address of the sender.
     * @param _token The token address being deposited.
     * @param _potentialBankValue The potential new bank value if the deposit is accepted.
     * @param _bankCap The maximum bank cap.
     */
    error BankCapReachedError(address _sender, address _token, uint256 _potentialBankValue, uint256 _bankCap);

    /**
     * @notice Error thrown when the current withdrawal request would exceed the withdraw
     * limit set in the deployment step.
     * @param _sender The address of the sender.
     * @param _token The token address being withdrawn.
     * @param _amount The amount that was attempted to be withdrawn.
     * @param _limit The maximum single withdrawal limit.
     */
    error WithdrawLimitExceededError(address _sender, address _token, uint256 _amount, uint256 _limit);

    /**
     * @notice Error thrown when a withdrawal request attempts to withdraw an amount that
     * exceeds the funds stored in the contract.
     * @param _sender The address of the sender.
     * @param _token The token address being withdrawn.
     * @param _funds The funds in the sender's vault.
     * @param _amount The amount that was attempted to be withdrawn.
     */
    error InsufficientFundsError(address _sender, address _token, uint256 _funds, uint256 _amount);

    /**
     * @notice Error thrown if a transfer was not successful.
     * @param _sender The address of the sender.
     * @param _token The token address being transferred.
     * @param _amount The amount that was attempted to be transferred.
     */
    error TransferError(address _sender, address _token, uint256 _amount);

    /**
     * @notice Error thrown if the Chainlink oracle returns a stale response.
     */
    error OracleStaleResponse();

    /**
     * @notice Error thrown if the Chainlink oracle returns an incoherent response.
     */
    error OracleIncoherentResponse();

    /**
     * @notice Deploys the contract by setting the bank cap and the maximum single withdrawal limit.
     * @param _bankCap The maximum value that this contract can hold.
     * @param _maxWithdrawLimit The maximum amount that a user can withdraw from their vault in a single transaction.
     * @param _owner The address of the owner of the contract.
     * @param _priceFeed The address of the Chainlink price feed contract for ETH/USD.
     * @param _usdcToken The address of the USD Coin (USDC) token contract on the Ethereum network.
     */
    constructor(
        uint256 _bankCap,
        uint256 _maxWithdrawLimit,
        address _owner,
        address _priceFeed,
        IERC20 _usdcToken
    ) Ownable(_owner) {
        if (_bankCap < _maxWithdrawLimit) {
            revert ConstructorPreconditionError("Exp. bankCap >= maxWithdrawLimit");
        }

        i_bankCap = _bankCap;
        i_maxSingleWithdrawLimit = _maxWithdrawLimit;
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        i_USDCToken = _usdcToken;
    }

    /**
     * @notice Allows contract to receive ETH directly.
     */
    receive() external payable override {
        depositEther();
    }

    /**
     * @notice Get balance for the sender for a given token.
     * @param _token The token address to check the balance for (use address(0) for ETH).
     * @return funds_ The balance of the sender.
     */
    function getMyFunds(address _token) external view override returns (uint256 funds_) {
        funds_ = s_vault[_token][msg.sender];
    }

    /**
     * @notice Get funds stored in vault for a given address for a given token.
     * @param _address The address to check the funds for.
     * @param _token The token address to check the balance for (use address(0) for ETH).
     * @return funds_ The funds stored in vault for the given address.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getFundsForAddress(
        address _address,
        address _token
    ) external view override onlyOwner returns (uint256 funds_) {
        funds_ = s_vault[_token][_address];
    }

    /**
     * @notice Get this contract's deposit count.
     * @return depositCount_ The deposit count.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getDepositCount() external view override onlyOwner returns (uint256 depositCount_) {
        depositCount_ = s_depositCount;
    }

    /**
     * @notice Get this contract's withdraw count.
     * @return withdrawCount_ The withdraw count.
     * @dev Sensitive information, should only be accessible to owner.
     */
    function getWithdrawCount() external view override onlyOwner returns (uint256 withdrawCount_) {
        withdrawCount_ = s_withdrawCount;
    }

    /**
     * @notice Deposits the value in the address' ETH vault.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     */
    function depositEther() public payable override {
        uint256 potentialBankValue = getBalanceEther() + msg.value;
        if (potentialBankValue > i_bankCap) {
            revert BankCapReachedError(msg.sender, ETH_ADDRESS, potentialBankValue, i_bankCap);
        }

        _updateDepositValues(msg.sender, ETH_ADDRESS, msg.value);
        emit DepositSuccess(msg.sender, ETH_ADDRESS, msg.value);
    }

    /**
     * @notice Deposits the value in the address' USDC vault.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     * @param _amount The amount in USDC to deposit.
     */
    function depositUsdc(uint256 _amount) public payable override {
        uint256 potentialBankValue = getBalanceUsd() + _convertEthToUsd(_amount, _getLatestPriceEthToUsd());
        if (potentialBankValue > i_bankCap) {
            revert BankCapReachedError(msg.sender, address(i_USDCToken), potentialBankValue, i_bankCap);
        }

        _updateDepositValues(msg.sender, address(i_USDCToken), _amount);
        i_USDCToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit DepositSuccess(msg.sender, address(i_USDCToken), _amount);
    }

    /**
     * @notice Withdraws amount from the address' ETH vault.
     * @dev Reverts with WithdrawLimitExceededError if the amount exceeds the single withdraw limit.
     * @dev Reverts with InsufficientFundsError if the withdraw would exceed the available balance.
     * @dev Reverts with TransferError if the transfer was not successful.
     * @dev Emits a WithdrawSuccess event upon success.
     * @param _amount The amount to withdraw.
     */
    function withdrawEther(uint256 _amount) public override nonReentrant {
        if (_amount > i_maxSingleWithdrawLimit) {
            revert WithdrawLimitExceededError(msg.sender, ETH_ADDRESS, _amount, i_maxSingleWithdrawLimit);
        }

        uint256 funds = s_vault[ETH_ADDRESS][msg.sender];
        if (_amount > funds) {
            revert InsufficientFundsError(msg.sender, ETH_ADDRESS, funds, _amount);
        }

        _updateWithdrawValues(msg.sender, ETH_ADDRESS, _amount);

        address payable payableSender = payable(msg.sender);
        (bool success, ) = payableSender.call{ value: _amount }("");
        if (!success) {
            revert TransferError(msg.sender, ETH_ADDRESS, _amount);
        }

        emit WithdrawSuccess(msg.sender, ETH_ADDRESS, _amount);
    }

    /**
     * @notice Withdraws the value in the address' USDC vault.
     * @dev Reverts with WithdrawLimitExceededError if the amount exceeds the single withdraw limit.
     * @dev Reverts with InsufficientFundsError if the withdraw would exceed the available balance.
     * @dev Reverts with TransferError if the transfer was not successful.
     * @dev Emits a WithdrawSuccess event upon success.
     * @param _amount The amount in USDC to withdraw.
     */
    function withdrawUsdc(uint256 _amount) public override nonReentrant {
        uint256 maxSingleWithdrawLimitUsd = _convertEthToUsd(i_maxSingleWithdrawLimit, _getLatestPriceEthToUsd());
        if (_amount > maxSingleWithdrawLimitUsd) {
            revert WithdrawLimitExceededError(msg.sender, address(i_USDCToken), _amount, maxSingleWithdrawLimitUsd);
        }

        uint256 funds = s_vault[address(i_USDCToken)][msg.sender];
        if (_amount > funds) {
            revert InsufficientFundsError(msg.sender, address(i_USDCToken), funds, _amount);
        }

        _updateWithdrawValues(msg.sender, address(i_USDCToken), _amount);

        i_USDCToken.safeTransfer(msg.sender, _amount);

        emit WithdrawSuccess(msg.sender, address(i_USDCToken), _amount);
    }

    /**
     * @notice Get balance in this contract in ETH.
     * @return balance_ The balance of this contract in ETH.
     */
    function getBalanceEther() public view override returns (uint256 balance_) {
        balance_ = address(this).balance;
    }

    /**
     * @notice Get balance in this contract in USD.
     * @return balance_ The balance of this contract in USD.
     */
    function getBalanceUsd() public view override returns (uint256 balance_) {
        balance_ = _convertEthToUsd(getBalanceEther(), _getLatestPriceEthToUsd());
    }

    /**
     * @notice Get the latest price from the Chainlink price feed.
     * @dev Reverts with OracleIncoherentResponse if the response is incoherent.
     * @dev Reverts with OracleStaleResponse if the response is stale.
     * @return price_ The latest price.
     */
    function _getLatestPriceEthToUsd() internal view returns (uint256 price_) {
        (, int256 price, , uint256 updatedAt, ) = s_priceFeed.latestRoundData();

        if (price < 0) {
            revert OracleIncoherentResponse();
        }

        if (updatedAt < block.timestamp - ORACLE_STALE_TIME_SECONDS) {
            revert OracleStaleResponse();
        }

        price_ = uint256(price);
    }

    /**
     * @notice Converts an amount in ETH to USD.
     * @param _amountEth The amount in ETH.
     * @param _ethPrice The current price of ETH in USD.
     * @return amountUsd_ The equivalent amount in USD.
     */
    function _convertEthToUsd(uint256 _amountEth, uint256 _ethPrice) internal pure returns (uint256 amountUsd_) {
        amountUsd_ = (_amountEth * _ethPrice) / ETH_DECIMAL_FACTOR;
    }

    /**
     * @notice Update the relevant variables when a deposit is successful.
     * @param _address The address of the user making the deposit.
     * @param _token The token address being deposited.
     * @param _amount The amount deposited.
     */
    function _updateDepositValues(address _address, address _token, uint256 _amount) private {
        s_vault[_token][_address] += _amount;
        ++s_depositCount;
    }

    /**
     * @notice Update the relevant variables when a withdrawal is successful.
     * @param _address The address of the user making the withdrawal.
     * @param _token The token address being withdrawn.
     * @param _amount The amount withdrawn.
     */
    function _updateWithdrawValues(address _address, address _token, uint256 _amount) private {
        s_vault[_token][_address] -= _amount;
        ++s_withdrawCount;
    }
}
