// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IVaultFactory} from "./IVaultFactory.sol";

interface IVaultSubscriptionManager {
    struct PaymentTokenSettings {
        uint256 baseSubscriptionCost;
        bool isAvailableForPayment;
    }

    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
        mapping(address => uint256) accountSubscriptionCosts;
    }

    struct VaultSubscriptionManagerStorage {
        uint64 basePeriodDuration;
        IVaultFactory vaultFactory;
        // TokensSettings
        EnumerableSet.AddressSet paymentTokens;
        mapping(address => PaymentTokenSettings) paymentTokensSettings;
        // Subscription duration factors
        mapping(uint256 => uint256) subscriptionDurationFactors;
        // Accounts subscription data
        mapping(address => AccountSubscriptionData) accountsSubscriptionData;
    }

    error InvalidBasePeriodDuration(uint256 newBasePeriodDurationValue);
    error TokenNotConfigured(address tokenAddr);
    error InvalidTokenPaymentStatus(address tokenAddr, bool newStatus);
    error NotAvailableForPayment(address tokenAddr);
    error ZeroDuration();
    error InvalidSubscriptionDuration(uint256 duration);
    error NotAVault(address vaultAddr);
    error NotEnoughNativeCurrency(uint256 requiredAmount_, uint256 availableAmount_);
    error ZeroTokensRecipient();

    event BasePeriodDurationUpdated(uint256 newBasePeriodDurationValue);
    event TokenPaymentStatusUpdated(address indexed tokenAddr, bool isAvailableForPayment);
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
    event AccountSubscriptionCostUpdated(
        address indexed account,
        address indexed token,
        uint256 baseTokenSubscriptionCost
    );
    event SubscriptionExtended(
        address indexed account,
        address indexed tokenAddr,
        uint256 duration,
        uint256 totalCost,
        uint64 newEndTime
    );

    function updateTokenPaymentStatus(address token_, bool newStatus_) external;

    function updateSubscriptionDurationFactor(uint256 duration_, uint256 factor_) external;

    function buySubscription(address account_, address token_, uint256 duration_) external payable;

    function getTokenBaseSubscriptionCost(address token_) external view returns (uint256);

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) external view returns (uint256);

    function getSubscriptionCost(
        address account_,
        address token_,
        uint256 duration_
    ) external view returns (uint256 totalCost_);

    function getAccountSubscriptionEndTime(address account_) external view returns (uint256);

    function isAvailableForPayment(address token_) external view returns (bool);

    function hasActiveSubscription(address account_) external view returns (bool);

    function hasExpiredSubscription(address account_) external view returns (bool);
}
