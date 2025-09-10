// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

/**
 * @title IVaultSubscriptionManager
 * @notice Interface for the VaultSubscriptionManager contract
 */
interface IVaultSubscriptionManager is ISubscriptionManager {
    /**
     * @notice Initialization parameters for the VaultSubscriptionManager contract.
     * @param vaultFactoryAddr The address of the VaultFactory contract.
     * @param subscriptionCreators Initial list of addresses allowed to create subscriptions.
     * @param tokensPaymentInitData Initialization data for the tokens payment module.
     * @param sbtPaymentInitData Initialization data for the SBT payment module.
     * @param sigSubscriptionInitData Initialization data for the signature-based subscription module.
     */
    struct VaultSubscriptionManagerInitData {
        address vaultFactoryAddr;
        address[] subscriptionCreators;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }

    /**
     * @notice Thrown when the provided account is not a vault.
     * @param vaultAddr Invalid vault address.
     */
    error NotAVault(address vaultAddr);
    /**
     * @notice Thrown when the caller is not the vault factory.
     * @param vaultAddr The invalid vault factory address.
     */
    error NotAVaultFactory(address vaultAddr);
    /**
     * @notice Thrown when a subscription for a vault is inactive.
     * @param account The vault with the inactive subscription.
     */
    error InactiveVaultSubscription(address account);

    /**
     * @notice Emitted when the vault factory address is updated.
     * @param vaultFactory The new vault factory address.
     */
    event VaultFactoryUpdated(address vaultFactory);

    /**
     * @notice A function to buy a subscription for a vault using an SBT owned by a specific address.
     * @param vault_ The address of the vault to buy a subscription for.
     * @param sbt_ The SBT contract address.
     * @param sbtOwner_ The address of the SBT owner paying for the subscription.
     * @param tokenId_ The token ID used for the payment.
     */
    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        address sbtOwner_,
        uint256 tokenId_
    ) external;

    /**
     * @notice A function to buy a subscription for an account using an EIP-712 signature.
     * @param sender_ The initiator of the subscription purchase.
     * @param vault_ The address of the vault to buy a subscription for.
     * @param duration_ Duration in seconds for which to extended the subscription.
     * @param signature_ The EIP-712 signature signed by the subscription signer.
     */
    function buySubscriptionWithSignature(
        address sender_,
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) external;

    /**
     * @notice A function to retrieve the address of the stored vault factory.
     * @return The vault factory contract address.
     */
    function getVaultFactory() external view returns (address);
}
