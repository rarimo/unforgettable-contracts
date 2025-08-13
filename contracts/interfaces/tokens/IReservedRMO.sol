// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IReservedRMO is IERC20 {
    /**
     * @notice Thrown when reserved tokens amount per address is zero.
     */
    error ZeroReservedTokensAmountPerAddress();

    /**
     * @notice Thrown when the provided address is not a valid vault.
     * @param vaultAddress The address checked for vault validity.
     */
    error NotAVault(address vaultAddress);

    /**
     * @notice Thrown when the sender address is not a valid RMO token.
     * @param sender The address checked for RMO token validity.
     */
    error NotRMOToken(address sender);

    /**
     * @notice Thrown when tokens have already been minted for the specified vault.
     * @param vaultAddress The vault address for which tokens were already minted.
     */
    error TokensAlreadyMintedForThisVault(address vaultAddress);

    /**
     * @notice Thrown when the RMO token has already been set.
     */
    error RMOTokenAlreadySet();

    /**
     * @notice Emitted when the reserved tokens amount per address is updated.
     * @param newTokensAmount The new amount of reserved tokens per address.
     */
    event ReservedTokensPerAddressUpdated(uint256 newTokensAmount);

    /**
     * @notice Emitted when the RMO token address is set.
     * @param rmoToken The address of the newly set RMO token.
     */
    event RMOTokenSet(address rmoToken);

    /**
     * @notice Pauses the contract, disabling transfer operations.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract, enabling operations.
     */
    function unpause() external;

    /**
     * @notice Sets the RMO token address.
     * @param rmoToken_ The address of the RMO token to set.
     */
    function setRMOToken(address rmoToken_) external;

    /**
     * @notice Sets the amount of reserved tokens per address.
     * @param newReservedTokensAmount_ The new reserved tokens amount per address.
     */
    function setReservedTokensPerAddress(uint256 newReservedTokensAmount_) external;

    /**
     * @notice Mints reserved tokens for a specific vault address.
     *  Can only be called once per vault.
     *  Subsequent calls for the same vault will revert.
     * @param vaultAddress_ The address of the vault to mint tokens for.
     */
    function mintReservedTokens(address vaultAddress_) external;

    /**
     * @notice Burns a specified amount of reserved tokens from an account.
     * @dev Only the `rmoToken` contract can call this function.
     * @param account_ The account from which tokens will be burned.
     * @param amount_ The amount of tokens to burn.
     */
    function burnReservedTokens(address account_, uint256 amount_) external;

    /**
     * @notice Returns the address of the RMO token.
     * @return The address of the RMO token.
     */
    function getRMOToken() external view returns (address);

    /**
     * @notice Returns the address of the vault factory.
     * @return The address of the vault factory.
     */
    function getVaultFactory() external view returns (address);

    /**
     * @notice Returns the amount of reserved tokens per address.
     * @return The reserved tokens amount per address.
     */
    function getReservedTokensPerAddress() external view returns (uint256);

    /**
     * @notice Returns the amount of reserved tokens minted for a specific vault address.
     * @param vaultAddress_ The vault address to check.
     * @return The amount of tokens minted for the vault.
     */
    function getMintedAmount(address vaultAddress_) external view returns (uint256);

    /**
     * @notice Returns the address of the current implementation contract.
     * @return The address of the implementation contract.
     */
    function implementation() external view returns (address);
}
