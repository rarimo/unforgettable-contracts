// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeReceiver} from "@wormhole/interfaces/IWormholeRelayer.sol";
import {IMessanger} from "./IMessanger.sol";

interface ISubscriptionsStateReceiver is IWormholeReceiver, IMessanger {
    struct SubscriptionsStateReceiverInitData {
        address wormholeRelayer;
        address subscriptionsSynchronizer;
        uint16 sourceChainId;
    }

    function rootInHistory(bytes32 smtRoot_) external view returns (bool);
}
