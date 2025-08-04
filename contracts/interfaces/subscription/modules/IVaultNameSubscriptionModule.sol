// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVaultNameSubscriptionModule {
    struct VaultPaymentTokenUpdateEntry {
        address paymentToken;
        uint256 baseVaultNameCost;
    }

    error NotAVault(address vaultAddr);
    error NotAVaultFactory(address vaultAddr);
    error VaultNameAlreadyTaken(string vaultName);
    error VaultNameTooShort(string vaultName);
    error VaultNameUnchanged(string vaultName);
    error InactiveVaultSubscription(address account);

    event VaultNameRetentionPeriodUpdated(uint256 newVaultNameRetentionPeriod);
    event VaultPaymentTokenUpdated(address indexed paymentToken, uint256 baseVaultNameCost);
    event VaultNameUpdated(address indexed account, string vaultName);
    event VaultNameReassigned(
        string vaultName,
        address indexed oldVault,
        address indexed newVault
    );

    function setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) external;
    function updateVaultPaymentTokens(
        VaultPaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) external;
    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable;
    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_
    ) external payable;
    function getVaultNameRetentionPeriod() external view returns (uint64);
    function getVaultFactory() external view returns (address);
    function getTokenBaseVaultNameCost(address token_) external view returns (uint256);
    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) external view returns (uint256);
    function getVaultName(address account_) external view returns (string memory);
    function getVault(string memory vaultName_) external view returns (address);
    function hashUpdateVaultName(
        address account_,
        string memory vaultName_,
        uint256 nonce_
    ) external view returns (bytes32);
    function isVaultNameAvailable(string memory name_) external view returns (bool);
}
