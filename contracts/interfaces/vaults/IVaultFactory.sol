// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVaultFactory {
    error ZeroAddress();

    event VaultImplementationUpdated(address newVaultImplementation);
    event TokenLimitAmountUpdated(address indexed tokenAddr, uint256 newLimitAmount);
    event VaultDeployed(
        address indexed vaultCreator,
        address indexed vault,
        address vaultMasterKey
    );

    function updateVaultImplementation(address newVaultImpl_) external;

    function updateTokenLimitAmount(address token_, uint256 newLimitAmount_) external;

    function deployVault(
        address masterKey_,
        address paymentToken_,
        uint64 initialSubscriptionDuration_,
        string memory vaultName_
    ) external payable returns (address vaultAddr_);

    function getVaultCountByCreator(address vaultCreator_) external view returns (uint256);

    function getVaultsByCreatorPart(
        address vaultCreator_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    function isVault(address vaultAddr) external view returns (bool);

    function getTokenLimitAmount(address token_) external view returns (uint256);

    function getVaultSubscriptionManager() external view returns (address);

    function getVaultImplementation() external view returns (address);

    function predictVaultAddress(
        address implementation_,
        address vaultCreator_,
        uint256 nonce_
    ) external view returns (address);

    function implementation() external view returns (address);

    function getDeployVaultSalt(address creator_, uint256 nonce_) external pure returns (bytes32);
}
