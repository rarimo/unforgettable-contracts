// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeReceiver} from "@wormhole/interfaces/IWormholeRelayer.sol";

interface ISubscriptionsStateReceiver is IWormholeReceiver {
    struct SubscriptionsStateReceiverInitData {
        address wormholeRelayer;
        address subscriptionsSynchronizer;
        uint16 sourceChainId;
    }
}
