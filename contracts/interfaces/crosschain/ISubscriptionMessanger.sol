// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISubscriptionMessanger
 * @notice Interface for cross-chain subscription messaging.
 */
interface ISubscriptionMessanger {
    /**
     * @notice Struct for synchronization messages.
     * @param syncTimestamp The timestamp of the synchronization.
     * @param subscriptionsSMTRoot The Sparse Merkle Tree root of the subscriptions.
     */
    struct SyncMessage {
        uint256 syncTimestamp;
        bytes32 subscriptionsSMTRoot;
    }
}
