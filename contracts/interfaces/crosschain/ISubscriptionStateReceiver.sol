// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeReceiver} from "@wormhole/interfaces/IWormholeRelayer.sol";

interface ISubscriptionStateReceiver is IWormholeReceiver {
    struct SubscriptionStateReceiverInitData {
        address wormholeRelayer;
        address subscriptionStateSynchronizer;
        uint16 sourceChainId;
    }
}
