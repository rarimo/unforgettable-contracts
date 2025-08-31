// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionsSynchronizer {
    struct SubscriptionsSynchronizerInitData {
        address wormholeRelayer;
        address[] subscriptionManagers;
        Destination[] destinations;
    }

    struct Destination {
        uint16 chainId;
        address targetAddress;
    }

    struct SyncMessage {
        uint256 syncTimestamp;
        bytes32 subscriptionsSMTRoot;
    }

    function sync(uint16 targetChain_) external payable;

    function saveSubscriptionData(
        address account_,
        uint64 startTime_,
        uint64 endTime_,
        bool isNewSubscription_
    ) external;

    function addSubscriptionManager(address subscriptionManager_) external;

    function removeSubscriptionManager(address subscriptionManager_) external;

    function addDestination(Destination calldata destination_) external;

    function removeDestination(uint16 chainId_) external;
}
