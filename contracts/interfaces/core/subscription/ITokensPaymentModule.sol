// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

/**
 * @title ITokensPaymentModule
 * @notice Interface for the TokensPaymentModule contract
 */
interface ITokensPaymentModule is IBaseSubscriptionModule {
    /**
     * @notice Data structure storing data used to update the payment token configuration.
     * @param paymentToken The payment token contract address.
     * @param baseSubscriptionCost Base cost for a single subscription period in token units.
     */
    struct PaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseSubscriptionCost;
    }

    /**
     * @notice Data structure storing data used to update the duration-based factor
     *         for adjusting subscription costs.
     * @param duration The subscription duration in seconds.
     * @param factor Multiplicative factor applied to the subscription cost.
     */
    struct DurationFactorUpdateEntry {
        uint64 duration;
        uint256 factor;
    }

    /**
     * @notice Initialization parameters for the TokensPaymentModule contract.
     * @param basePaymentPeriod Base subscription billing period used for subscription cost calculation.
     * @param paymentTokenEntries List of payment tokens and their base subscription costs.
     * @param durationFactorEntries List of duration-based factors to adjust subscription pricing.
     */
    struct TokensPaymentModuleInitData {
        uint64 basePaymentPeriod;
        PaymentTokenUpdateEntry[] paymentTokenEntries;
        DurationFactorUpdateEntry[] durationFactorEntries;
    }

    /**
     * @notice Data structure storing base and account-specific subscription costs for a payment token.
     * @param baseSubscriptionCost Base cost of a single subscription period.
     * @param accountsSubscriptionCost Mapping from account addresses to their saved subscription costs.
     */
    struct PaymentTokenData {
        uint256 baseSubscriptionCost;
        mapping(address => uint256) accountsSubscriptionCost;
    }

    /**
     * @notice Thrown when an unsupported payment token is provided.
     * @param token The unsupported payment token contract address.
     */
    error TokenNotSupported(address token);
    /**
     * @notice Thrown when trying to add an already supported payment token.
     * @param token The duplicate payment token contract address.
     */
    error PaymentTokenAlreadyAdded(address token);
    /**
     * @notice Thrown when a provided duration is less than a base payment period.
     * @param duration The invalid subscription duration.
     */
    error InvalidSubscriptionDuration(uint256 duration);
    /**
     * @notice Thrown when a provided duration is zero.
     */
    error ZeroDuration();

    /**
     * @notice Emitted when the base payment period is updated.
     * @param newBasePaymentPeriod The updated base payment period.
     */
    event BasePaymentPeriodUpdated(uint256 newBasePaymentPeriod);
    /**
     * @notice Emitted when a new payment token is added.
     * @param paymentToken A new payment token contract address.
     */
    event PaymentTokenAdded(address indexed paymentToken);
    /**
     * @notice Emitted when a payment token is removed.
     * @param paymentToken The removed payment token contract address.
     */
    event PaymentTokenRemoved(address indexed paymentToken);
    /**
     * @notice Emitted when the token base subscription cost is updated.
     * @param paymentToken The payment token address to update base cost for.
     * @param baseSubscriptionCost The updated base subscription cost.
     */
    event BaseSubscriptionCostUpdated(address indexed paymentToken, uint256 baseSubscriptionCost);
    /**
     * @notice Emitted when the payment token status is updated.
     * @param paymentToken The payment token address to update the status for.
     * @param isAvailableForPayment The flag indicating whether the token is available or not.
     */
    event TokenPaymentStatusUpdated(address indexed paymentToken, bool isAvailableForPayment);
    /**
     * @notice Emitted when the subscription duration factor is updated.
     * @param duration The subscription duration to update the factor for.
     * @param factor The updated multiplicative factor applied to the subscription cost.
     */
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
    /**
     * @notice Emitted when tokens are withdrawn from the module.
     * @param paymentToken The token address withdrawn.
     * @param recipient The address of the recipient of withdrawn tokens.
     * @param amount The amount withdrawn.
     */
    event TokensWithdrawn(address indexed paymentToken, address recipient, uint256 amount);
    /**
     * @notice Emitted when an account's saved subscription cost for a token is updated.
     * @param account The account for which the subscription cost was updated.
     * @param paymentToken The token for which account subscription cost was updated.
     * @param baseTokenSubscriptionCost The updated account base subscription cost.
     */
    event AccountTokenSubscriptionCostUpdated(
        address indexed account,
        address indexed paymentToken,
        uint256 baseTokenSubscriptionCost
    );
    /**
     * @notice Emitted when a subscription is bought with a payment token.
     * @param paymentToken The address of the token used for payment.
     * @param buyer The address of the payer.
     * @param tokensAmount The total subscription cost payed.
     */
    event SubscriptionBoughtWithToken(
        address indexed paymentToken,
        address indexed buyer,
        uint256 tokensAmount
    );

    /**
     * @notice A function to buy a subscription for an account using a supported payment token.
     * @param account_ The account to buy a subscription for.
     * @param paymentToken_ The address of the ERC-20 token used for payment.
              Use `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` to pay in ETH.
     * @param duration_ Duration in seconds for which to extended the subscription.
     */
    function buySubscription(
        address account_,
        address paymentToken_,
        uint64 duration_
    ) external payable;

    /**
     * @notice A function to retrieve the base payment period used for subscription calculations.
     * @return Base payment period in seconds.
     */
    function getBasePaymentPeriod() external view returns (uint64);

    /**
     * @notice A function to retrieve the subscription cost factor for a specific duration.
     * @param duration_ Subscription duration to query.
     * @return Multiplicative factor applied to the subscription cost.
     */
    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256);

    /**
     * @notice A function to retrieve a list of all supported payment tokens.
     * @return An array of supported payment token addresses.
     */
    function getPaymentTokens() external view returns (address[] memory);

    /**
     * @notice A function to compute the total subscription cost for a given account, token, and duration.
     * @param account_ Account address for which to calculate the subscription cost.
     * @param paymentToken_ The token address to be used for payment.
     * @param duration_ Subscription duration.
     * @return totalCost_ Total subscription cost in token units.
     */
    function getSubscriptionCost(
        address account_,
        address paymentToken_,
        uint64 duration_
    ) external view returns (uint256 totalCost_);

    /**
     * @notice A function to retrieve the base subscription cost for a provided token.
     * @param paymentToken_ The payment token address to query.
     * @return Base subscription cost for a provided token.
     */
    function getTokenBaseSubscriptionCost(address paymentToken_) external view returns (uint256);

    /**
     * @notice A function to retrieve the saved subscription cost for provided account and token (if any).
     * @param account_ The account address to query.
     * @param paymentToken_ The payment token address to query.
     * @return The account's saved subscription cost in token units.
     */
    function getAccountSavedSubscriptionCost(
        address account_,
        address paymentToken_
    ) external view returns (uint256);

    /**
     * @notice A function to retrieve the base subscription cost for provided account and token.
     * @dev Returns minimum of current token base cost and any saved account-specific cost.
     * @param account_ The account address to query.
     * @param paymentToken_ The payment token address to query.
     * @return Base subscription cost in token units.
     */
    function getAccountBaseSubscriptionCost(
        address account_,
        address paymentToken_
    ) external view returns (uint256);

    /**
     * @notice A function to check whether a token is supported for subscription payments.
     * @param paymentToken_ Token address to check.
     * @return `true` if the token is supported, `false` otherwise.
     */
    function isSupportedToken(address paymentToken_) external view returns (bool);
}
