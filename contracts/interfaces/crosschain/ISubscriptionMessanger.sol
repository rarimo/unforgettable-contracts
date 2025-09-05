// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionMessanger {
    struct SyncMessage {
        uint256 syncTimestamp;
        bytes32 subscriptionsSMTRoot;
    }
}
