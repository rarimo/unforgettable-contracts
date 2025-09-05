// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IVaultFactory
 * @notice Interface for the VaultFactory contract
 */
interface IVaultFactory {
    /**
     * @notice Thrown when zero address is provided when not allowed.
     */
    error ZeroAddress();
    /**
     * @notice Thrown when a provided vault name is shorter than the minimum required length.
     * @param vaultName The provided vault name.
     */
    error VaultNameTooShort(string vaultName);
    /**
     * @notice Thrown when a provided vault name is already taken.
     * @param vaultName The provided vault name.
     */
    error VaultNameAlreadyTaken(string vaultName);

    /**
     * @notice Emitted when the vault implementation is updated.
     * @param newVaultImplementation The address of the new vault implementation.
     */
    event VaultImplementationUpdated(address newVaultImplementation);
    /**
     * @notice Emitted when the token deposit limit is updated.
     * @param tokenAddr The token contract address.
     * @param newLimitAmount The updated deposit limit.
     */
    event TokenLimitAmountUpdated(address indexed tokenAddr, uint256 newLimitAmount);
    /**
     * @notice Emitted when a new vault is deployed.
     * @param vaultCreator The address that initiated the vault creation.
     * @param vault The deployed vault address.
     * @param vaultMasterKey The master key of the deployed vault.
     * @param vaultName The name of the deployed vault.
     */
    event VaultDeployed(
        address indexed vaultCreator,
        address indexed vault,
        address vaultMasterKey,
        string vaultName
    );

    /**
     * @notice A function to update the vault implementation contract address.
     * @param newVaultImpl_ Address of the new vault implementation.
     */
    function updateVaultImplementation(address newVaultImpl_) external;

    /**
     * @notice A function to update the deposit limit for the provided token.
     * @param token_ Token contract address.
     * @param newLimitAmount_ New deposit limit.
     */
    function updateTokenLimitAmount(address token_, uint256 newLimitAmount_) external;

    /**
     * @notice A function to deploy a new vault with an initial subscription paid with tokens.
     * @param masterKey_ The vault master key.
     * @param paymentToken_ Token address used to purchase the initial subscription.
     * @param initialSubscriptionDuration_ Duration of the initial subscription in seconds.
     * @param vaultName_ Name of the vault.
     * @return vaultAddr_ The address of the deployed vault.
     */
    function deployVault(
        address masterKey_,
        address paymentToken_,
        uint64 initialSubscriptionDuration_,
        string memory vaultName_
    ) external payable returns (address vaultAddr_);

    /**
     * @notice A function to deploy a new vault with an initial subscription paid using an SBT.
     * @param masterKey_ The vault master key.
     * @param sbt_ The SBT contract address used to purchase the initial subscription.
     * @param tokenId_ The token ID of the SBT used for subscription.
     * @param vaultName_ Name of the vault.
     * @return vaultAddr_ The address of the deployed vault.
     */
    function deployVaultWithSBT(
        address masterKey_,
        address sbt_,
        uint256 tokenId_,
        string memory vaultName_
    ) external returns (address vaultAddr_);

    /**
     * @notice A function to deploy a new vault with an initial subscription activated with an EIP-712 signature.
     * @param masterKey_ The vault master key.
     * @param initialSubscriptionDuration_ Duration of the initial subscription in seconds.
     * @param signature_ EIP-712 signature authorizing the subscription.
     * @param vaultName_ Name of the vault.
     * @return vaultAddr_ The address of the deployed vault.
     */
    function deployVaultWithSignature(
        address masterKey_,
        uint64 initialSubscriptionDuration_,
        bytes memory signature_,
        string memory vaultName_
    ) external returns (address vaultAddr_);

    /**
     * @notice A function to retrieve the number of vaults created by a specific creator.
     * @param vaultCreator_ The creator address.
     * @return Number of vaults created.
     */
    function getVaultCountByCreator(address vaultCreator_) external view returns (uint256);

    /**
     * @notice A function to retrieve a paginated list of vaults created by the provided address.
     * @param vaultCreator_ The creator address.
     * @param offset_ Starting index.
     * @param limit_ Number of results to return.
     * @return Array of vault addresses created by the `vaultCreator_`.
     */
    function getVaultsByCreatorPart(
        address vaultCreator_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    /**
     * @notice A function to check whether a provided address is a valid deployed vault.
     * @param vaultAddr_ Address to check.
     * @return `true` if the address is a vault, `false` otherwise.
     */
    function isVault(address vaultAddr_) external view returns (bool);

    /**
     * @notice A function to retrieve the deposit limit amount for the provided token.
     * @param token_ Token address to query.
     * @return The token deposit limit.
     */
    function getTokenLimitAmount(address token_) external view returns (uint256);

    /**
     * @notice A function to retrieve the address of the stored vault subscription manager.
     * @return The vault subscription manager address.
     */
    function getVaultSubscriptionManager() external view returns (address);

    /**
     * @notice A function to retrieve the current vault implementation address.
     * @return The vault implementation address.
     */
    function getVaultImplementation() external view returns (address);

    /**
     * @notice A function to predict the deterministic address of a vault before deployment.
     * @param masterKey_ The vault master key.
     * @param nonce_ Creator’s nonce.
     * @return Predicted vault address.
     */
    function predictVaultAddress(
        address masterKey_,
        uint256 nonce_
    ) external view returns (address);

    /**
     * @notice A function to retrieve the current factory implementation (UUPS).
     * @return Implementation contract address.
     */
    function implementation() external view returns (address);

    /**
     * @notice A function to check whether a vault name is available.
     * @param name_ The name to check.
     * @return `true` if the name is not taken, `false` otherwise.
     */
    function isVaultNameAvailable(string memory name_) external view returns (bool);

    /**
     * @notice A function to retrieve the registered name of a vault.
     * @param vault_ Vault address to query.
     * @return The vault name.
     */
    function getVaultName(address vault_) external view returns (string memory);

    /**
     * @notice A function to retrieve the vault address registered with the provided name.
     * @param vaultName_ The vault name to query.
     * @return The vault address.
     */
    function getVaultByName(string memory vaultName_) external view returns (address);

    /**
     * @notice A function to compute the salt used for deterministic vault deployment.
     * @param masterKey_ Vault master key.
     * @param nonce_ Creator’s nonce.
     * @return The computed deployment salt.
     */
    function getDeployVaultSalt(
        address masterKey_,
        uint256 nonce_
    ) external pure returns (bytes32);
}
