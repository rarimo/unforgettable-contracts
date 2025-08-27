// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionSynchronizer {
    struct Destination {
        uint16 chainId;
        address targetAddress;
    }

    struct SubscriptionSynchronizerInitData {
        address wormholeRelayer;
        address[] subscriptionManagers;
        Destination[] destinations;
    }

    function sync(uint16 targetChain_) external payable;
}
