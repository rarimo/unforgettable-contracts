// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../ISubscriptionManager.sol";

interface IVaultSubscriptionManager is ISubscriptionManager {
    struct PaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseSubscriptionCost;
    }

    struct SBTTokenUpdateEntry {
        address sbtToken;
        uint64 subscriptionTimePerToken;
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
    error NotAVault(address vaultAddr);
    error NotEnoughNativeCurrency(uint256 requiredAmount_, uint256 availableAmount_);
    error ZeroAddr();
    error NotAnOwnerForSBT(address tokenAddr);
    error NotSupportedSBT(address tokenAddr);
    error NotATokenOwner(address tokenAddr, address userAddr, uint256 tokenId);

    event BasePeriodDurationUpdated(uint256 newBasePeriodDurationValue);
    event SubscriptionSignerUpdated(address indexed newSubscriptionSigner);
    event PaymentTokenUpdated(address indexed paymentToken, uint256 baseSubscriptionCost);
    event SBTTokenUpdated(address indexed sbtToken, uint64 subscriptionTimePerToken);
    event TokenPaymentStatusUpdated(address indexed tokenAddr, bool isAvailableForPayment);
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
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
    event SubscriptionBoughtWithSBT(
        address indexed sbtToken,
        address indexed sender,
        uint256 tokenId
    );
    event SubscriptionBoughtWithSignature(address indexed sender, uint64 duration, uint256 nonce);

    function setSubscriptionSigner(address newSubscriptionSigner_) external;

    function updatePaymentTokens(PaymentTokenUpdateEntry[] calldata paymentTokenEntries_) external;

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external;

    function updateTokenPaymentStatus(address token_, bool newStatus_) external;

    function updateSubscriptionDurationFactor(uint64 duration_, uint256 factor_) external;

    function withdrawTokens(address tokenAddr_, address to_, uint256 amount_) external;

    function getVaultFactory() external view returns (address);

    function getTokenBaseSubscriptionCost(address token_) external view returns (uint256);

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) external view returns (uint256);

    function isSupportedSBT(address sbtToken_) external view returns (bool);

    function getSubscriptionTimePerSBT(address sbtToken_) external view returns (uint64);

    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) external view returns (bytes32);
}
