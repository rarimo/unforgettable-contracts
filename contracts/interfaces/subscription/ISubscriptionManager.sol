// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionManager {
    struct PaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseSubscriptionCost;
    }

    struct PaymentTokenSettings {
        uint256 baseSubscriptionCost;
        bool isAvailableForPayment;
    }

    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
        mapping(address => uint256) accountSubscriptionCosts;
    }

    error InvalidBasePeriodDuration(uint256 newBasePeriodDurationValue);
    error TokenNotConfigured(address tokenAddr);
    error InvalidTokenPaymentStatus(address tokenAddr, bool newStatus);
    error NotAvailableForPayment(address tokenAddr);
    error ZeroDuration();
    error InvalidSubscriptionDuration(uint256 duration);
    error ZeroAddr();

    event BasePeriodDurationUpdated(uint256 newBasePeriodDurationValue);
    event PaymentTokenUpdated(address indexed paymentToken, uint256 baseSubscriptionCost);
    event TokenPaymentStatusUpdated(address indexed tokenAddr, bool isAvailableForPayment);
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
    event TokensWithdrawn(address indexed tokenAddr, address recipient, uint256 amount);
    event SubscriptionExtended(address indexed account, uint64 duration, uint64 newEndTime);
    event AccountSubscriptionCostUpdated(
        address indexed account,
        address indexed token,
        uint256 baseTokenSubscriptionCost
    );
    event SubscriptionBoughtWithToken(
        address indexed paymentToken,
        address indexed sender,
        uint256 tokensAmount
    );

    function updatePaymentTokens(PaymentTokenUpdateEntry[] calldata paymentTokenEntries_) external;
    function updateTokenPaymentStatus(address token_, bool newStatus_) external;
    function updateSubscriptionDurationFactor(uint64 duration_, uint256 factor_) external;
    function withdrawTokens(address tokenAddr_, address to_, uint256 amount_) external;
    function buySubscription(address account_, address token_, uint64 duration_) external payable;
    function getBasePeriodDuration() external view returns (uint64);
    function getPaymentTokens() external view returns (address[] memory);
    function getPaymentTokensSettings(
        address token_
    ) external view returns (PaymentTokenSettings memory);
    function implementation() external view returns (address);
    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256);
    function getTokenBaseSubscriptionCost(address token_) external view returns (uint256);
    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) external view returns (uint256);
    function getSubscriptionCost(
        address account_,
        address token_,
        uint64 duration_
    ) external view returns (uint256 totalCost_);
    function getAccountSubscriptionEndTime(address account_) external view returns (uint64);
    function isAvailableForPayment(address token_) external view returns (bool);
    function hasActiveSubscription(address account_) external view returns (bool);
    function hasSubscriptionDebt(address account_) external view returns (bool);
}
