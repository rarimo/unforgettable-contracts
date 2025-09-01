// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

/**
 * @title ISignatureSubscriptionModule
 * @notice Interface for the SignatureSubscriptionModule contract
 */
interface ISignatureSubscriptionModule is IBaseSubscriptionModule {
    /**
     * @notice Initialization parameters for the SignatureSubscriptionModule contract.
     * @param subscriptionSigner The address authorized to sign subscription purchase EIP-712 messages.
     */
    struct SigSubscriptionModuleInitData {
        address subscriptionSigner;
    }

    /**
     * @notice Emitted when the subscription signer is updated.
     * @param newSubscriptionSigner The new address authorized to sign subscription purchases.
     */
    event SubscriptionSignerUpdated(address indexed newSubscriptionSigner);
    /**
     * @notice Emitted when a subscription is bought with a signature.
     * @param sender The address submitting the signature.
     * @param duration Subscription extension duration in seconds.
     * @param nonce The nonce used in the signed message to prevent replay attacks.
     */
    event SubscriptionBoughtWithSignature(address indexed sender, uint64 duration, uint256 nonce);

    /**
     * @notice A function to buy a subscription for an account using an EIP-712 signature.
     * @param account_ The account to buy a subscription for.
     * @param duration_ Duration in seconds for which to extended the subscription.
     * @param signature_ The EIP-712 signature signed by the subscription signer.
     */
    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external;

    /**
     * @notice A function to retrieve the subscription signer address.
     * @return The address authorized to sign subscription purchase messages.
     */
    function getSubscriptionSigner() external view returns (address);

    /**
     * @notice A function to compute the EIP-712 hash for a subscription purchase message.
     * @param sender_ The address initiating the purchase.
     * @param duration_ The subscription duration.
     * @param nonce_ The nonce used in the subscription purchase message.
     * @return The EIP-712 hash of the purchase message to be signed by the subscription signer.
     */
    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) external view returns (bytes32);
}
