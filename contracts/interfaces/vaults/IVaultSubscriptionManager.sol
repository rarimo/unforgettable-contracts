// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../ISubscriptionManager.sol";

interface IVaultSubscriptionManager is ISubscriptionManager {
    struct PaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseSubscriptionCost;
        uint256 baseVaultNameCost;
    }

    struct SBTTokenUpdateEntry {
        address sbtToken;
        uint64 subscriptionTimePerToken;
    }

    struct PaymentTokenSettings {
        uint256 baseSubscriptionCost;
        uint256 baseVaultNameCost;
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
    error NotSupportedSBT(address tokenAddr);
    error NotATokenOwner(address tokenAddr, address userAddr, uint256 tokenId);
    error VaultNameAlreadyTaken(string vaultName);
    error VaultNameTooShort(string vaultName);
    error VaultNameUnchanged(string vaultName);

    event BasePeriodDurationUpdated(uint256 newBasePeriodDurationValue);
    event SubscriptionSignerUpdated(address indexed newSubscriptionSigner);
    event VaultNameRetentionPeriodUpdated(uint256 newVaultNameRetentionPeriod);
    event PaymentTokenUpdated(
        address indexed paymentToken,
        uint256 baseSubscriptionCost,
        uint256 baseVaultNameCost
    );
    event SBTTokenUpdated(address indexed sbtToken, uint64 subscriptionTimePerToken);
    event TokenPaymentStatusUpdated(address indexed tokenAddr, bool isAvailableForPayment);
    event SubscriptionDurationFactorUpdated(uint256 indexed duration, uint256 factor);
    event TokensWithdrawn(address indexed tokenAddr, address recipient, uint256 amount);
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
    event VaultNameUpdated(address indexed account, string vaultName);
    event VaultNameReassigned(
        string vaultName,
        address indexed oldVault,
        address indexed newVault
    );

    function setSubscriptionSigner(address newSubscriptionSigner_) external;

    function setVaultNameRetentionPeriod(uint256 newVaultNameRetentionPeriod_) external;

    function updatePaymentTokens(PaymentTokenUpdateEntry[] calldata paymentTokenEntries_) external;

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external;

    function updateTokenPaymentStatus(address token_, bool newStatus_) external;

    function updateSubscriptionDurationFactor(uint64 duration_, uint256 factor_) external;

    function withdrawTokens(address tokenAddr_, address to_, uint256 amount_) external;

    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable;

    function getBasePeriodDuration() external view returns (uint64);

    function getSubscriptionSigner() external view returns (address);

    function getVaultNameRetentionPeriod() external view returns (uint256);

    function getVaultFactory() external view returns (address);

    function implementation() external view returns (address);

    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256);

    function getTokenBaseSubscriptionCost(address token_) external view returns (uint256);

    function getTokenBaseVaultNameCost(address token_) external view returns (uint256);

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) external view returns (uint256);

    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) external view returns (uint256);

    function isSupportedSBT(address sbtToken_) external view returns (bool);

    function getSubscriptionTimePerSBT(address sbtToken_) external view returns (uint64);

    function getVaultName(address account_) external view returns (string memory);

    function getVault(string memory vaultName_) external view returns (address);

    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) external view returns (bytes32);

    function hashUpdateVaultName(
        address account_,
        string memory vaultName_,
        uint256 nonce_
    ) external view returns (bytes32);

    function isVaultNameAvailable(string memory name_) external view returns (bool);
}
