// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IVault
 * @notice Interface for the Vault contract
 */
interface IVault {
    /**
     * @notice Thrown when a vault doesn't have an active subscription.
     */
    error NoActiveSubscription();
    /**
     * @notice Thrown when zero amount is provided when not allowed.
     */
    error ZeroAmount();
    /**
     * @notice Thrown when a token amount exceeds the allowed limit.
     * @param token The token contract address.
     */
    error TokenLimitExceeded(address token);
    /**
     * @notice Thrown when trying to set the master key to the zero address.
     */
    error ZeroMasterKey();
    /**
     * @notice Thrown when trying to update the enabled status to the current value.
     */
    error InvalidNewEnabledStatus();
    /**
     * @notice Thrown when trying to deposit to the vault the is not currently enabled.
     */
    error VaultIsNotEnabled();

    /**
     * @notice Emitted when the vault master key is changed.
     * @param previousOwner Previous master key.
     * @param newOwner New master key.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /**
     * @notice Emitted when the vault is enabled or disabled.
     * @param enabled The flag to indicate whether the vault was enabled or disabled.
     */
    event EnabledStatusUpdated(bool enabled);
    /**
     * @notice Emitted when tokens are deposited to the vault.
     * @param token The token contract address.
     * @param sender The depositor address.
     * @param amount Amount deposited.
     */
    event TokensDeposited(address indexed token, address sender, uint256 amount);
    /**
     * @notice Emitted when tokens are withdrawn from the vault.
     * @param token The token address withdrawn.
     * @param recipient The withdrawal recipient address.
     * @param amount Amount withdrawn.
     */
    event TokensWithdrawn(address indexed token, address recipient, uint256 amount);

    /**
     * @notice A function to initialize the vault with a master key.
     * @param masterKey_ The initial master key.
     */
    function initialize(address masterKey_) external;

    /**
     * @notice A function to update the vault master key.
     * @param newMasterKey_ The new master key.
     * @param signature_ Signature from the current master key authorizing the change.
     */
    function updateMasterKey(address newMasterKey_, bytes memory signature_) external;

    /**
     * @notice A function to update the enabled status of the vault.
     * @param enabled_ New enabled status.
     * @param signature_ Signature from the master key authorizing the change.
     */
    function updateEnabledStatus(bool enabled_, bytes memory signature_) external;

    /**
     * @notice A function to withdraw tokens from the vault.
     * @param tokenAddr_ The token address to withdraw.
     * @param recipient_ The withdrawal recipient address.
     * @param tokensAmount_ The amount of tokens to withdraw.
     * @param signature_ Signature from the master key authorizing the withdrawal.
     */
    function withdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 tokensAmount_,
        bytes memory signature_
    ) external;

    /**
     * @notice A function to deposit tokens to the vault.
     * @param tokenAddr_ Address of the token to deposit.
     * @param amountToDeposit_ Amount to deposit.
     */
    function deposit(address tokenAddr_, uint256 amountToDeposit_) external payable;

    /**
     * @notice A function to retrieve the current master key.
     * @return Address of the vault master key.
     */
    function owner() external view returns (address);

    /**
     * @notice A function to retrieve the balance of the provided token in the vault.
     * @param tokenAddr_ Token contract address to query.
     * @return Balance of the token held by the vault.
     */
    function getBalance(address tokenAddr_) external view returns (uint256);

    /**
     * @notice A function to retrieve the stored vault factory address.
     * @return Address of the stored vault factory.
     */
    function getVaultFactory() external view returns (address);

    /**
     * @notice A function to check whether the vault is enabled.
     * @return `true` if the vault is enabled, `false` otherwise.
     */
    function isVaultEnabled() external view returns (bool);

    /**
     * @notice A function to compute the EIP-712 hash for a withdraw request.
     * @param tokenAddr_ The token address to withdraw.
     * @param recipient_ The withdrawal recipient address.
     * @param amount_ The amount of tokens to withdraw.
     * @param nonce_ The nonce used in the withdrawal request signature.
     * @return The EIP-712 hash of the withdrawal request to be signed by the vault owner.
     */
    function hashWithdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_
    ) external view returns (bytes32);

    /**
     * @notice A function to compute the EIP-712 hash for an enabled status update request.
     * @param enabled_ New enabled status.
     * @param nonce_ The nonce used in the enabled status update request signature.
     * @return The EIP-712 hash of the enabled status update request to be signed by the vault owner.
     */
    function hashUpdateEnabledStatus(
        bool enabled_,
        uint256 nonce_
    ) external view returns (bytes32);

    /**
     * @notice A function to compute the EIP-712 hash for a master key update request.
     * @param newMasterKey_ New master key.
     * @param nonce_ The nonce used in the master key update request signature.
     * @return The EIP-712 hash of the master key update request to be signed by the vault owner.
     */
    function hashUpdateMasterKey(
        address newMasterKey_,
        uint256 nonce_
    ) external view returns (bytes32);
}
