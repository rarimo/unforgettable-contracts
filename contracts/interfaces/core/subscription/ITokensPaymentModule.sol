// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

interface ITokensPaymentModule is IBaseSubscriptionModule {
    struct PaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseSubscriptionCost;
    }

    struct DurationFactorUpdateEntry {
        uint64 duration;
        uint256 factor;
    }

    struct TokensPaymentModuleInitData {
        uint64 basePaymentPeriod;
        PaymentTokenUpdateEntry[] paymentTokenEntries;
        DurationFactorUpdateEntry[] durationFactorEntries;
    }

    struct PaymentTokenData {
        uint256 baseSubscriptionCost;
        mapping(address => uint256) accountsSubscriptionCost;
    }

    error NotAvailableForPayment(address token);
    error TokenNotSupported(address token);
    error PaymentTokenAlreadyAdded(address token);
    error InvalidSubscriptionDuration(uint256 duration);
    error ZeroDuration();

    event BasePaymentPeriodUpdated(uint256 newBasePaymentPeriod);
    event PaymentTokenAdded(address indexed paymentToken);
    event PaymentTokenRemoved(address indexed paymentToken);
    event BaseSubscriptionCostUpdated(address indexed paymentToken, uint256 baseSubscriptionCost);
    event TokenPaymentStatusUpdated(address indexed paymentToken, bool isAvailableForPayment);
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
    event TokensWithdrawn(address indexed paymentToken, address recipient, uint256 amount);
    event AccountTokenSubscriptionCostUpdated(
        address indexed account,
        address indexed paymentToken,
        uint256 baseTokenSubscriptionCost
    );
    event SubscriptionBoughtWithToken(
        address indexed paymentToken,
        address indexed buyer,
        uint256 tokensAmount
    );

    function buySubscription(
        address account_,
        address paymentToken_,
        uint64 duration_
    ) external payable;

    function getBasePaymentPeriod() external view returns (uint64);

    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256);

    function getSubscriptionCost(
        address account_,
        address paymentToken_,
        uint64 duration_
    ) external view returns (uint256 totalCost_);

    function getTokenBaseSubscriptionCost(address paymentToken_) external view returns (uint256);

    function getAccountSavedSubscriptionCost(
        address account_,
        address paymentToken_
    ) external view returns (uint256);

    function getAccountBaseSubscriptionCost(
        address account_,
        address paymentToken_
    ) external view returns (uint256);

    function isSupportedToken(address paymentToken_) external view returns (bool);
}
