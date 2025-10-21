// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import { IUniversalRouter } from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IV4Quoter } from "@uniswap/v4-periphery/src/interfaces/IV4Quoter.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";

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
     * Bank cap is dynamically converted from ETH to USDC, assume that this value might fluctuate.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     * @param _amount The amount in USDC to deposit.
     */
    function depositUsdc(uint256 _amount) external;

    /**
     * @notice Deposits the value in the address' USDC vault by swapping from the source token.
     * Bank cap is dynamically converted from ETH to USDC, assume that this value might fluctuate.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a SwapSuccess event upon swapping the value.
     * @dev Emits a DepositSuccess event upon success.
     * @param _tokenIn The token to deposit.
     * @param _amount The amount of the token to deposit.
     */
    function depositArbitraryToken(address _tokenIn, uint128 _amount) external payable;

    /**
     * @notice Swaps an input value.
     * @dev Reverts with MultiTokenInputsNotSupported if the caller attempts to send ETH within this function.
     * @dev Emits a SwapSuccess event if the swap is executed successfully.
     * @param _key The PoolKey to execute this swap on.
     * @param _amountIn The amount to swap.
     * @param _minAmountOut The minimum amount to accept after a swap.
     * @param _deadline The maximum time that an user is willing to wait for the swap to complete.
     * @return amountOut_ The USDC amount actually deposited to the this contract.
     */
    function _swapExactInputSingle(
        PoolKey memory _key,
        uint128 _amountIn,
        uint128 _minAmountOut,
        uint48 _deadline
    ) external payable returns (uint256 amountOut_);

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
     * @notice Get balance in this contract in USDC.
     * @return balance_ The balance of this contract in USDC.
     */
    function getBalanceUsdc() external view returns (uint256 balance_);

    /**
     * @notice Get the total balance in this contract in USD.
     * @return balance_ The total balance of this contract in USD.
     */
    function getTotalBalanceUsd() external view returns (uint256 balance_);

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
     * @notice The fee to use for interacting with Uniswap pools.
     */
    uint24 internal constant UNISWAP_POOL_FEE = 3000;

    /**
     * @notice The tick spacing to use for interacting with Uniswap pools.
     */
    int24 internal constant UNISWAP_POOL_TICK_SPACING = 60;

    /**
     * @notice The time to wait from now to be used as a deadline for a swap.
     */
    int48 internal constant UNISWAP_DEADLINE_FROM_NOW = 30;

    /**
     * @notice The maximum value that this contract can hold.
     */
    uint256 private immutable i_bankCap;

    /**
     * @notice The maximum amount that a user can withdraw from their vault in a single transaction.
     */
    uint256 private immutable i_maxSingleWithdrawLimit;

    /**
     * @notice The Universal Router to interface with for swapping tokens.
     */
    IUniversalRouter private immutable i_router;

    /**
     * @notice The permit interface to use when approving swaps.
     */
    IPermit2 private immutable i_permit2;

    /**
     * @notice The quoter interface to use when quoting swaps.
     */
    IV4Quoter private immutable i_quoter;

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
     * @param _sender The address of the message sender.
     * @param _token The token address being deposited.
     * @param _amount The amount deposited.
     */
    event DepositSuccess(address indexed _sender, address indexed _token, uint256 _amount);

    /**
     * @notice Event emitted when a deposit is successful.
     * @param _sender The address of the message sender.
     * @param _tokenIn The token address being deposited by the user (before swap).
     * @param _amountIn The amount deposited before swap.
     * @param _tokenOut The token address being deposited in the contract (after swap).
     * @param _amountOut The amount deposited after swap.
     */
    event ArbitraryDepositSuccess(
        address indexed _sender,
        address indexed _tokenIn,
        uint256 _amountIn,
        address indexed _tokenOut,
        uint256 _amountOut
    );

    /**
     * @notice Event emitted when a withdraw is successful.
     * @param _sender The address of the message sender.
     * @param _token The token address being withdrawn.
     * @param _amount The amount withdrawn.
     */
    event WithdrawSuccess(address indexed _sender, address indexed _token, uint256 _amount);

    /**
     * @notice Event emitted when a token value has been swapped.
     * @param _sender The address of the message sender.
     * @param _token The token address being deposited.
     * @param _amount The amount deposited.
     */
    event SwapSuccess(address indexed _sender, address indexed _token, uint256 _amount);

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
     * @notice Error thrown if the contract caller attempts to operate with more
     * than one token at a time.
     * @param _sender The address of the sender.
     * @param _token The token address used.
     * @param _amount The amount that was attempted to be swapped.
     */
    error MultiTokenInputsNotSupported(address _sender, address _token, uint256 _amount);

    /**
     * @notice Error thrown if an error occurred when requesting a quote with Uniswap.
     * @param _sender The address of the sender.
     * @param _token The token address used.
     * @param _amount The amount that was attempted to be quoted.
     */
    error UniswapQuoteFailed(address _sender, address _token, uint256 _amount);

    /**
     * @notice Deploys the contract by setting the bank cap and the maximum single withdrawal limit.
     * @param _bankCap The maximum value that this contract can hold.
     * @param _maxWithdrawLimit The maximum amount that a user can withdraw from their vault in a single transaction.
     * @param _owner The address of the owner of the contract.
     * @param _priceFeed The address of the Chainlink price feed contract for ETH/USD.
     * @param _usdcToken The address of the USD Coin (USDC) token contract on the Ethereum network.
     * @param _router The address of the UniversalRouter contract.
     * @param _permit2 The address of the Permit2 contract.
     */
    constructor(
        uint256 _bankCap,
        uint256 _maxWithdrawLimit,
        address _owner,
        address _priceFeed,
        IERC20 _usdcToken,
        address payable _router,
        address _permit2,
        address _quoter
    ) Ownable(_owner) {
        if (_bankCap < _maxWithdrawLimit) {
            revert ConstructorPreconditionError("Exp. bankCap >= maxWithdrawLimit");
        }

        i_bankCap = _bankCap;
        i_maxSingleWithdrawLimit = _maxWithdrawLimit;
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        i_USDCToken = _usdcToken;
        i_router = IUniversalRouter(_router);
        i_permit2 = IPermit2(_permit2);
        i_quoter = IV4Quoter(_quoter);
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
        funds_ = s_vault[msg.sender][_token];
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
        funds_ = s_vault[_address][_token];
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
     * Bank cap is dynamically converted from ETH to USDC, assume that this value might fluctuate.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Emits a DepositSuccess event upon success.
     * @param _amount The amount in USDC to deposit.
     */
    function depositUsdc(uint256 _amount) public override {
        uint256 potentialBankValue = getBalanceUsdc() + _amount;
        uint256 usdcBankCap = _convertEthWeiToUsd(i_bankCap, _getLatestPriceEthToUsd());
        if (potentialBankValue > usdcBankCap) {
            revert BankCapReachedError(msg.sender, address(i_USDCToken), potentialBankValue, usdcBankCap);
        }

        _updateDepositValues(msg.sender, address(i_USDCToken), _amount);
        i_USDCToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit DepositSuccess(msg.sender, address(i_USDCToken), _amount);
    }

    /**
     * @notice Deposits the value in the address' USDC vault by swapping from the source token.
     * Bank cap is dynamically converted from ETH to USDC, assume that this value might fluctuate.
     * @dev Reverts with BankCapReachedError if the deposit would exceed the bank cap.
     * @dev Reverts with UniswapQuoteFailed if quote could not be acquired.
     * @dev Emits a SwapSuccess event upon swapping the value.
     * @dev Emits a ArbitraryDepositSuccess event upon success.
     * @param _tokenIn The token to deposit.
     * @param _amount The amount of the token to deposit.
     */
    function depositArbitraryToken(address _tokenIn, uint128 _amount) public payable override {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(_tokenIn),
            currency1: Currency.wrap(address(i_USDCToken)),
            fee: UNISWAP_POOL_FEE,
            tickSpacing: UNISWAP_POOL_TICK_SPACING,
            hooks: IHooks(address(0))
        });

        uint256 quotedUsdcAmount = _quoteTokenToUSDC(key, _amount);
        uint256 potentialBankValue = getBalanceUsdc() + quotedUsdcAmount;
        uint256 usdcBankCap = _convertEthWeiToUsd(i_bankCap, _getLatestPriceEthToUsd());
        if (potentialBankValue > usdcBankCap) {
            revert BankCapReachedError(msg.sender, address(i_USDCToken), potentialBankValue, usdcBankCap);
        }

        _updateDepositValues(msg.sender, address(i_USDCToken), quotedUsdcAmount);

        uint48 deadline = uint48(block.timestamp + uint48(UNISWAP_DEADLINE_FROM_NOW));
        _swapExactInputSingle(key, _amount, uint128(quotedUsdcAmount), deadline);

        emit ArbitraryDepositSuccess({
            _sender: msg.sender,
            _tokenIn: _tokenIn,
            _amountIn: _amount,
            _tokenOut: address(i_USDCToken),
            _amountOut: quotedUsdcAmount
        });
    }

    /**
     * @notice Swaps an input value.
     * @dev Reverts with MultiTokenInputsNotSupported if the caller attempts to send ETH within this function.
     * @dev Emits a SwapSuccess event if the swap is executed successfully.
     * @param _key The PoolKey to execute this swap on.
     * @param _amountIn The amount to swap.
     * @param _minAmountOut The minimum amount to accept after a swap.
     * @param _deadline The maximum time that an user is willing to wait for the swap to complete.
     * @return amountOut_ The USDC amount actually deposited to the this contract.
     */
    function _swapExactInputSingle(
        PoolKey memory _key,
        uint128 _amountIn,
        uint128 _minAmountOut,
        uint48 _deadline
    ) public override payable returns (uint256 amountOut_) {
        if (msg.value > 0 && Currency.unwrap(_key.currency0) != ETH_ADDRESS) {
            revert MultiTokenInputsNotSupported(msg.sender, Currency.unwrap(_key.currency0), _amountIn);
        }
        
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(IV4Router.ExactInputSingleParams({
            poolKey: _key,
            zeroForOne: true,
            amountIn: _amountIn,
            amountOutMinimum: _minAmountOut,
            hookData: bytes("")
        }));
        params[1] = abi.encode(_key.currency0, _amountIn);
        params[2] = abi.encode(_key.currency1, _minAmountOut);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        uint256 balanceBeforeSwap = i_USDCToken.balanceOf(address(this));

        if (Currency.unwrap(_key.currency0) != ETH_ADDRESS) {
            IERC20(Currency.unwrap(_key.currency0)).safeTransferFrom(msg.sender, address(this), _amountIn);
            IERC20(Currency.unwrap(_key.currency0)).safeIncreaseAllowance(address(i_permit2), _amountIn);
            i_permit2.approve(Currency.unwrap(_key.currency0), address(i_router), _amountIn, _deadline);
        }

        i_router.execute{value: _amountIn}(commands, inputs, _deadline);
        emit SwapSuccess(msg.sender, Currency.unwrap(_key.currency0), _amountIn);

        uint256 balanceAfterSwap = i_USDCToken.balanceOf(address(this));
        amountOut_ = balanceAfterSwap - balanceBeforeSwap;
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

        uint256 funds = s_vault[msg.sender][ETH_ADDRESS];
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
        uint256 usdcMaxSingleWithdrawLimit = _convertEthWeiToUsd(i_maxSingleWithdrawLimit, _getLatestPriceEthToUsd());
        if (_amount > usdcMaxSingleWithdrawLimit) {
            revert WithdrawLimitExceededError(msg.sender, address(i_USDCToken), _amount, usdcMaxSingleWithdrawLimit);
        }

        uint256 funds = s_vault[msg.sender][address(i_USDCToken)];
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
     * @notice Get balance in this contract in USDC.
     * @return balance_ The balance of this contract in USDC.
     */
    function getBalanceUsdc() public view override returns (uint256 balance_) {
        balance_ = i_USDCToken.balanceOf(address(this));
    }

    /**
     * @notice Get the total balance in this contract in USD.
     * @return balance_ The total balance of this contract in USD.
     */
    function getTotalBalanceUsd() public view override returns (uint256 balance_) {
        balance_ = _convertEthWeiToUsd(getBalanceEther(), _getLatestPriceEthToUsd()) + getBalanceUsdc();
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

        if (updatedAt + ORACLE_STALE_TIME_SECONDS < block.timestamp) {
            revert OracleStaleResponse();
        }

        price_ = uint256(price);
    }

    /**
     * @notice Get a quote from a token to USDC (given the appropriate pool key).
     * @dev Make sure to always use a PoolKey with USDC as the output.
     * @dev Reverts with UniswapQuoteFailed if quote could not be acquired.
     * @param _key The PoolKey to use to interact with Uniswap.
     * @param _amountIn The amount to quote.
     * @return amountOut_ The quoted value.
     */
    function _quoteTokenToUSDC(PoolKey memory _key, uint128 _amountIn) internal view returns (uint256 amountOut_) {
        IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
            poolKey: _key,
            zeroForOne: true,
            exactAmount: _amountIn,
            hookData: bytes("")
        });
        
        try i_quoter.quoteExactInputSingle(params) returns (uint256 amountOut, uint256) {
            amountOut_ = amountOut;
        } catch {
            revert UniswapQuoteFailed(msg.sender, Currency.unwrap(_key.currency0), _amountIn);
        }
    }

    /**
     * @notice Converts an amount in ETH to USD.
     * @param _amountEthWei The amount in ETH (Wei).
     * @param _ethPrice The current price of ETH in USD.
     * @return amountUsd_ The equivalent amount in USD.
     */
    function _convertEthWeiToUsd(uint256 _amountEthWei, uint256 _ethPrice) internal pure returns (uint256 amountUsd_) {
        amountUsd_ = (_amountEthWei * _ethPrice) / 1e20;
    }

    /**
     * @notice Update the relevant variables when a deposit is successful.
     * @param _address The address of the user making the deposit.
     * @param _token The token address being deposited.
     * @param _amount The amount deposited.
     */
    function _updateDepositValues(address _address, address _token, uint256 _amount) private {
        s_vault[_address][_token] += _amount;
        ++s_depositCount;
    }

    /**
     * @notice Update the relevant variables when a withdrawal is successful.
     * @param _address The address of the user making the withdrawal.
     * @param _token The token address being withdrawn.
     * @param _amount The amount withdrawn.
     */
    function _updateWithdrawValues(address _address, address _token, uint256 _amount) private {
        s_vault[_address][_token] -= _amount;
        ++s_withdrawCount;
    }
}
