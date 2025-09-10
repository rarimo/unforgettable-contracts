// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {IBaseSubscriptionModule} from "./subscription/IBaseSubscriptionModule.sol";

/**
 * @title IBaseSideChainSubscriptionManager
 * @notice Base interface for managing subscriptions on a side chain.
 */
interface IBaseSideChainSubscriptionManager is IBaseSubscriptionModule {
    /**
     * @notice Initialization data for the base side chain subscription manager.
     * @param subscriptionsStateReceiver The address of the subscriptions state receiver.
     * @param sourceSubscriptionManager The address of the source subscription manager.
     */
    struct BaseSideChainSubscriptionManagerInitData {
        address subscriptionsStateReceiver;
        address sourceSubscriptionManager;
    }

    /**
     * @notice Event emitted when a subscription is synced.
     * @param account The account whose subscription was synced.
     * @param startTime The start time of the subscription.
     * @param endTime The end time of the subscription.
     */
    event SubscriptionSynced(address indexed account, uint64 startTime, uint64 endTime);
    /**
     * @notice Event emitted when the subscriptions state receiver is updated.
     * @param subscriptionsStateReceiver The address of the updated subscriptions state receiver.
     */
    event SubscriptionsStateReceiverUpdated(address indexed subscriptionsStateReceiver);
    /**
     * @notice Event emitted when the source subscription manager is updated.
     * @param sourceSubscriptionManager The address of the updated source subscription manager.
     */
    event SourceSubscriptionManagerUpdated(address indexed sourceSubscriptionManager);

    /**
     * @notice Thrown when an unknown SMT root is encountered.
     * @param root The unknown root.
     */
    error UnknownRoot(bytes32 root);
    /**
     * @notice Thrown when an invalid SMT proof is encountered.
     */
    error InvalidSMTProof();
    /**
     * @notice Thrown when an invalid proof key is encountered.
     */
    error InvalidProofKey();
    /**
     * @notice Thrown when an invalid proof value is encountered.
     */
    error InvalidProofValue();

    /**
     * @notice A function to pause the contract.
     */
    function pause() external;

    /**
     * @notice A function to unpause the contract.
     */
    function unpause() external;

    /**
     * @notice Synchronizes a subscription across chains.
     * @param account_ The account whose subscription is to be synchronized.
     * @param subscriptionData_ The subscription data to be synchronized.
     * @param proof_ The Sparse Merkle Tree proof validating the subscription data.
     */
    function syncSubscription(
        address account_,
        AccountSubscriptionData calldata subscriptionData_,
        SparseMerkleTree.Proof calldata proof_
    ) external;

    /**
     * @notice A function to get the address of the current implementation.
     * @return The address of the current implementation.
     */
    function implementation() external view returns (address);
}
