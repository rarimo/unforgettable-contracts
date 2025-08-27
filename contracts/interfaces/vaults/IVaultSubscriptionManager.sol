// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

interface IVaultSubscriptionManager is ISubscriptionManager {
    struct VaultPaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseVaultNameCost;
    }

    struct VaultSubscriptionManagerInitData {
        address vaultFactoryAddr;
        uint64 vaultNameRetentionPeriod;
        address[] subscriptionCreators;
        VaultPaymentTokenUpdateEntry[] vaultPaymentTokenEntries;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }

    error NotAVault(address vaultAddr);
    error NotAVaultFactory(address vaultAddr);
    error VaultNameAlreadyTaken(string vaultName);
    error VaultNameTooShort(string vaultName);
    error VaultNameUnchanged(string vaultName);
    error InactiveVaultSubscription(address account);

    event VaultFactoryUpdated(address vaultFactory);
    event VaultNameRetentionPeriodUpdated(uint256 newVaultNameRetentionPeriod);
    event VaultNameCostUpdated(address indexed paymentToken, uint256 baseVaultNameCost);
    event VaultNameUpdated(address indexed account, string vaultName);
    event VaultNameReassigned(
        string vaultName,
        address indexed oldVault,
        address indexed newVault
    );

    function setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) external;

    function updateVaultPaymentTokens(
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_
    ) external;

    function updateVaultName(
        address vault_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable;

    function updateVaultName(
        address vault_,
        address token_,
        string memory vaultName_
    ) external payable;

    function getVaultFactory() external view returns (address);

    function getVaultNameRetentionPeriod() external view returns (uint64);

    function getVaultName(address vault_) external view returns (string memory);

    function getVaultByName(string memory vaultName_) external view returns (address);

    function getTokenBaseVaultNameCost(address paymentToken_) external view returns (uint256);

    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) external view returns (uint256);

    function isVaultNameAvailable(string memory name_) external view returns (bool);

    function hashUpdateVaultName(
        address account_,
        string memory vaultName_,
        uint256 nonce_
    ) external view returns (bytes32);
}
